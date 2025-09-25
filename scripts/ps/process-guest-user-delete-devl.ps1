<#
    .SYNOPSIS
    A script to remove expired credentials from App Registrations
     
    .DESCRIPTION
    Leverage Microsoft Graph API and PowerShell to fetch a list of credentials (Certificates and Secrets) that are on Application Registrations, established expired credentials and remove these.
#>
param (
    [string]$MiClientId,
    [string]$DcrImmutableId,
    [string]$DceUri,
    [string]$LogTableName
)

# --- Start variables
$userDetails = @()

# --- Start Functions
function Write-LogInfo($logentry) {
    Write-Output "$(get-date -Format "yyyy-MM-dd HH:mm:ss K") - $($logentry)"
}

function PostLogAnalyticsData()
{   
    param (
        [Parameter(Mandatory=$true)][string]$logBody,
        [Parameter(Mandatory=$true)][string]$dcrImmutableId,
        [Parameter(Mandatory=$true)][string]$dceURI,
        [Parameter(Mandatory=$true)][string]$table
        )

    # Retrieving bearer token for the system-assigned managed identity
    $bearerToken = (Get-AzAccessToken -ResourceUrl "https://monitor.azure.com").Token

    $headers = @{
        "Authorization" = "Bearer $bearerToken";
        "Content-Type" = "application/json"
    }

    $method = "POST"
    $uri = "$dceURI/dataCollectionRules/$dcrImmutableId/streams/Custom-$table"+"?api-version=2023-01-01";
    Invoke-RestMethod -Uri $uri -Method $method -Body $logBody -Headers $headers;
}

function GetDaysInactive($lastLoginDate) {
    if ($null -eq $lastLoginDate) {
        return 0
    }
    return ((Get-Date) - ($lastLoginDate) | Select-Object -ExpandProperty TotalDays) -as [int]
}

function IsToBeDeleted($daysSinceCreated, $daysSinceLastLogin, $hasLoggedIn) {
    # If user has not logged in after 7 days of creation
    if ($daysSinceCreated -gt 7 && $hasLoggedIn -eq $false) {
        return $true
    }

    # if user has not logged in for over 30 days
    if ($daysSinceLastLogin -gt 30) {
        return $true
    }

    return $false
}

# --- Start Script Execution
Write-LogInfo("Script execution started")

# Authenticate with the credentials object
try 
{
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
catch 
{
  write-error "$($_.Exception)"
  throw "$($_.Exception)"
}


$group = Get-EntraGroup -Filter "displayName eq 'MoJo-External-Sync-Legal-Aid-Agency-Staff'"

$groupMembers = Get-MgGroupMember -GroupId $group.Id

foreach ($member in $groupMembers) {
    $user = Get-MgUser -UserId $member.Id -Property ID, DisplayName, UserPrincipalName, SignInActivity, CompanyName, JobTitle, Department, CreatedDateTime

    $LastLoginDate = $user.SignInActivity.LastSignInDateTime

    $DaysInactive = GetDaysInactive($LastLoginDate);
    $DaysSinceCreated = GetDaysInactive($user.CreatedDateTime);
    $isToBeDeleted = IsToBeDeleted($DaysSinceCreated, $DaysInactive, ($null -ne $LastLoginDate))

    if ($isToBeDeleted -eq $true) {
        
        $removal = "Removed"
        
        try {
            Remove-MgUser -UserId $user.Id
        }
        catch
        {
            $removal = "$($_.Exception)"
        }

        $userDetails += [PSCustomObject]@{
            id                = $user.Id
            displayname       = $user.DisplayName
            userprincipalname = $user.UserPrincipalName
            createddatetime   = $user.CreatedDateTime
            dayssincecreated  = $DaysSinceCreated
            lastlogindate     = $LastLoginDate
            daysinactive      = $DaysInactive
            companyname       = $user.CompanyName
            jobtitle          = $user.JobTitle
            department        = $user.Department
            cleanup           = $removal
            TimeGenerated     = $ExpiredCred.TimeGenerated
        }
    }
}


Write-LogInfo("$(([PSObject[]]($userDetails)).Count) Total Expired Credentials Found (expired over 30 days).")

# Convert the list of each Certificates & secrets for each App Registration into JSON format so we can send it to Log Analytics
Write-LogInfo("Convert Credentials list to JSON")
$userDetailsJSON = ConvertTo-Json @($userDetails)

Write-LogInfo("Post data to Log Analytics")

function GroupPostResults($postData) {
    for ($i = 0; $i -lt $postData.Count; $i += 500) {
        $batchNumber = ([Math]::Min($i+499, $postData.Count-1))
        $postDataBatch = $postData[$i..$batchNumber]

        $json = $postDataBatch | ConvertTo-Json -Depth 10

        PostLogAnalyticsData -logBody $json -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName
        
        Write-LogInfo("Sent batch from $($i+1) to $($batchNumber+1))")   
    }
}

GroupPostResults($userDetailsJSON)

Write-LogInfo("Script execution finished")
