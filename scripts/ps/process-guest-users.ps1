<#
    .SYNOPSIS
    A script to send a list of Guest User details to Log Analytics
    
    .DESCRIPTION
    Leverage Microsoft Graph API and PowerShell to fetch a list of Guest Usersto understand the state of our Guest Users and add observability and automation on top.
#>
param (
    [string]$MiClientId,
    [string]$DcrImmutableId,
    [string]$DceUri,
    [string]$LogTableName
)

# --- Start variables
$timeStamp = Get-Date -format o

# --- Start Functions
function Write-LogInfo($logentry) {
    Write-Output "$(get-date -Format "yyyy-MM-dd HH:mm:ss K") - $($logentry)"
}

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

function GetDaysInactive($lastLoginDate) {
    if ($null -eq $lastLoginDate) {
        return 0
    }
    return ((Get-Date) - ($lastLoginDate) | Select-Object -ExpandProperty TotalDays) -as [int]
}

# --- Start Script Execution
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

Write-LogInfo("Query Users with Get-MgUser.")

$users = Get-MgUser -Filter "userType eq 'Guest'" -All -Property ID, DisplayName, Mail, UserPrincipalName, AccountEnabled, CreatedDateTime, ExternalUserState, SignInActivity

Write-LogInfo("Update User Objects.")

$usersList = foreach ($user in $users) {

    $LastLoginDate = $user.SignInActivity.LastSignInDateTime

    $DaysInactive = GetDaysInactive($LastLoginDate);

    $daysSinceInvitedAndNotRegistered = $null
    if ("PendingAcceptance" -ne $user.ExternalUserState) {
        $daysSinceInvitedAndNotRegistered = 0
    }
    else {
        $daysSinceInvitedAndNotRegistered = ((Get-Date) - ($user.CreatedDateTime) | Select-Object -ExpandProperty TotalDays) -as [int]
    }

    [PSCustomObject]@{
        displayname                           = $user.DisplayName
        objectid                              = $user.ID
        mail                                  = $user.Mail
        userPrincipleName                     = $user.UserPrincipalName
        accountEnabled                        = $user.AccountEnabled
        createdDateTime                       = $user.CreatedDateTime
        externalUserState                     = $user.ExternalUserState
        lastLoginDate                         = $LastLoginDate
        hasLoggedIn                           = ($LastLoginDate ? $True : $False)
        daysSinceInvitedAndNotRegistered      = $daysSinceInvitedAndNotRegistered
        daysInactive                          = $DaysInactive
        isInactiveAfterPolicyDays             = (($DaysInactive -gt 90) ? $True : $False)
        isNotActivatedAfterPolicyDays         = (($daysSinceInvitedAndNotRegistered -gt 30) ? $True : $False)
        isInactiveAfterExternalPolicyDays     = (($DaysInactive -gt 395) ? $True : $False)
        isNotActivatedAfterExternalPolicyDays = (($daysSinceInvitedAndNotRegistered -gt 30) ? $True : $False)
        TimeGenerated                         = $timeStamp
    }    
}

Write-LogInfo("$(([PSObject[]]($usersList)).Count) Total Users Found.")

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

GroupPostResults($usersList)

Write-LogInfo("Script execution finished")
