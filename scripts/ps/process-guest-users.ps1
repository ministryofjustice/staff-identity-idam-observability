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

# --- Start Script Execution
Write-LogInfo("Script execution started")


Write-LogInfo("Authenticate with the credentials object.")
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
        isdaysSinceInvitedAndNotRegistered    = (($daysSinceInvitedAndNotRegistered -gt 30) ? $True : $False)
        isInactiveAfterExternalPolicyDays     = (($DaysInactive -gt 395) ? $True : $False)
        isNotActivatedAfterExternalPolicyDays = (($daysSinceInvitedAndNotRegistered -gt 30) ? $True : $False)
        TimeGenerated                         = $timeStamp
    }    
}

Write-LogInfo("$(([PSObject[]]($usersList)).Count) Total Users Found.")

# Convert the list of each Certificates & secrets for each App Registration into JSON format so we can send it to Log Analytics
Write-LogInfo("Convert Users list to JSON")
$splitAt = [Math]::Round($usersList.Count / 10)
$guestUserDetails1, $guestUserDetails2, $guestUserDetails3, $guestUserDetails4, $guestUserDetails5, $guestUserDetails6, $guestUserDetails7, $guestUserDetails8, $guestUserDetails9, $guestUserDetails10 = $usersList.Where(
 { $_ },
 'Split', $splitAt
)

$guestUserDetailsJSON1 = $guestUserDetails1 | ConvertTo-Json
$guestUserDetailsJSON2 = $guestUserDetails2 | ConvertTo-Json
$guestUserDetailsJSON3 = $guestUserDetails3 | ConvertTo-Json
$guestUserDetailsJSON4 = $guestUserDetails4 | ConvertTo-Json
$guestUserDetailsJSON5 = $guestUserDetails5 | ConvertTo-Json
$guestUserDetailsJSON6 = $guestUserDetails6 | ConvertTo-Json
$guestUserDetailsJSON7 = $guestUserDetails7 | ConvertTo-Json
$guestUserDetailsJSON8 = $guestUserDetails8 | ConvertTo-Json
$guestUserDetailsJSON9 = $guestUserDetails9 | ConvertTo-Json
$guestUserDetailsJSON10 = $guestUserDetails10 | ConvertTo-Json

Write-LogInfo("Post data to Log Analytics")
PostLogAnalyticsData -logBody $guestUserDetailsJSON1 -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName

PostLogAnalyticsData -logBody $guestUserDetailsJSON2 -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName

PostLogAnalyticsData -logBody $guestUserDetailsJSON3 -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName

PostLogAnalyticsData -logBody $guestUserDetailsJSON4 -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName

PostLogAnalyticsData -logBody $guestUserDetailsJSON5 -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName

PostLogAnalyticsData -logBody $guestUserDetailsJSON6 -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName

PostLogAnalyticsData -logBody $guestUserDetailsJSON7 -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName

PostLogAnalyticsData -logBody $guestUserDetailsJSON8 -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName

PostLogAnalyticsData -logBody $guestUserDetailsJSON9 -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName

PostLogAnalyticsData -logBody $guestUserDetailsJSON10 -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName

Write-LogInfo("Script execution finished")
