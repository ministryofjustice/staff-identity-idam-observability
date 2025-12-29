<#
    .SYNOPSIS
    A script that gets owners, roles and information about access packages
     
    .DESCRIPTION
    Leverage Microsoft Graph API and PowerShell to fetch a list Catalogs, Access packages and groups #>

    param(
        [string]$MIclientId,
        [string]$DcrImmutableId,
        [string]$DceUri,
        [string]$LogTableName
    )
    
    
    #Function to write log info
    function Write-LogInfo($logentry) {
        Write-Output "$(get-date -Format "yyyy-MM-dd HH:mm:ss K") - $($logentry)"
    }
    
    #Function to post to log analytics in stages
    function GroupPostResults($postData) {
        for ($i = 0; $i -lt $postData.Count; $i += 500) {
            $batchNumber = ([Math]::Min($i + 499, $postData.Count - 1))
            $postDataBatch = $postData[$i..$batchNumber]
    
            $json = $postDataBatch | ConvertTo-Json -Depth 10
    
            PostLogAnalyticsData -logBody $json -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName
            
            Write-LogInfo("Sent batch from $($i+1) to $($batchNumber+1))")   
        }
    }
    
    # Post data function
    function PostLogAnalyticsData() {   
        param (
            [Parameter(Mandatory = $true)][string]$logBody,
            [Parameter(Mandatory = $true)][string]$dcrImmutableId,
            [Parameter(Mandatory = $true)][string]$dceURI,
            [Parameter(Mandatory = $true)][string]$table
        )
    
        # Retrieving bearer token for the system-assigned managed identity
        $bearerToken = (Get-AzAccessToken -ResourceUrl "https://monitor.azure.com").Token
    
        $headers = @{
            "Authorization" = "Bearer $bearerToken";
            "Content-Type"  = "application/json"
        }
    
        $method = "POST"
        $uri = "$dceURI/dataCollectionRules/$dcrImmutableId/streams/Custom-$table" + "?api-version=2023-01-01";
        Invoke-RestMethod -Uri $uri -Method $method -Body $logBody -Headers $headers;
    }

    #Run Azure authentication

Write-LogInfo("Script execution started")
Write-LogInfo("Authenticate with the credentials object.")
try {
    Write-LogInfo("Authenticate to Azure")
    # Ensures you do not inherit an AzContext in your runbook
    Disable-AzContextAutosave -Scope Process

    # Connect to Azure with user-assigned managed identity
    Connect-AzAccount -Identity -AccountId $MiClientId

    $context = (Connect-AzAccount -Identity -AccountId $MiClientId).context
    $context = Set-AzContext -SubscriptionName $context.Subscription -DefaultProfile $context

    Connect-MgGraph -Identity -ClientId $MiClientId
    Write-LogInfo("Context is $context")
} 
catch {
    write-error "$($_.Exception)"
    throw "$($_.Exception)"
}

# ===== T1 ROLE NAMES =====
$roleNames = @(
    "Application Administrator",
    "Attribute Assignment Administrator",
    "Authentication Administrator",
    "Authentication Policy Administrator",
    "Conditional Access Administrator",
    "Global Administrator",
    "Privileged Authentication Administrator",
    "Privileged Role Administrator",
    "Security Administrator",
    "User Administrator",
    "Cloud Application Administrator"
)



#Get the Roles a list of the roles we're after, scope to what T1 roles
$allRoleDefs = Get-MgRoleManagementDirectoryRoleDefinition -All
$targetRoleDefs = $allRoleDefs | Where-Object { $roleNames -contains $_.DisplayName }
if (-not $targetRoleDefs) { throw "No role definitions matched. Check display names in your tenant locale." }


#Map Role Id's to name
$roleIdToName = @{}
foreach ($rd in $targetRoleDefs) { $roleIdToName[$rd.Id] = $rd.DisplayName }
#Get a list of the permanent assignments mapped to the role
$permAssignments = Get-MgRoleManagementDirectoryRoleAssignment -All | Where-Object { $roleIdToName.ContainsKey($_.RoleDefinitionId) }

#Create empty array to store info
$results = @()


foreach ($assignment in $permAssignments) {
    # Creating variables
    $EntraRole   = $targetRoleDefs | Where-Object { $_.id -eq $assignment.RoleDefinitionId }
    $principalID = $assignment.PrincipalId

    # Defaults so we don't append $null unintentionally
    $obj  = $null
    $type = $null

    try {
        Write-Output "Trying to get a user in directory for this Principal ID"
        $user = Get-MgUser -UserId $principalID -ErrorAction Stop
        $obj  = $user.UserPrincipalName
        $type = "User"
    }
    catch {
        try {
            Write-Output "Unable to find a user for this, trying Group"
            $group = Get-MgGroup -GroupId $principalID -ErrorAction Stop
            $obj   = $group.DisplayName
            $type  = "Group"
        }
        catch {
            try {
                Write-Output "Unable to find a Group for ID, trying Service Principal"
                $spn  = Get-MgServicePrincipal -ServicePrincipalId $principalID -ErrorAction Stop
                $obj  = $spn.DisplayName
                $type = "SPN"
            }
            catch {
                Write-Warning "Principal $principalID not found as User, Group, or Service Principal"
            }
        }
    }
    # Send the results to the report
    $results += [PSCustomObject]@{
        Name     = $obj
        Type     = $type
        # Choose the right property for your role object:
        # Many role def objects use DisplayName; adjust if yours uses 'Name'
        RoleName = $EntraRole.DisplayName
    }
}
Write-LogInfo("Post data to Log Analytics")
GroupPostResults($results)
Write-LogInfo("Script execution finished")