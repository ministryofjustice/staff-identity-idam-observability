<#
    .SYNOPSIS
    A script to retrieve user statistics and post to Log Analytics
     
    .DESCRIPTION
    Leverage Microsoft Graph API and PowerShell to fetch user info, split these with a few operations and post to Log Analytics.
#>
param (
    [string]$MiClientId,
    [string]$DcrImmutableId,
    [string]$DceUri,
    [string]$LogTableName,
    [string]$mailSender,
    [string]$mailRecipient
)

# --- Start variables
$timeStamp = Get-Date -format o
$thresholdDate = (Get-Date).AddYears(-1)

# --- Start Functions
function Write-LogInfo($logEntry) {
    Write-Output "$(get-date -Format "yyyy-MM-dd HH:mm:ss K") - $($logEntry)"
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

    Connect-Entra -Identity -ClientId $MiClientId
    Write-LogInfo("Context is $context")
} 
catch 
{
  write-error "$($_.Exception)"
  throw "$($_.Exception)"
}

## Below runs each query as a filter. This is because Get-MgUser -All uses too much memory for the runbook to handle
# All user objects
Get-MgUser -ConsistencyLevel eventual -CountVariable allCount -Top 1 | Out-Null
# Service
Get-MgUser -Filter "startsWith(UserPrincipalName, 'svc_')" -ConsistencyLevel eventual -CountVariable serviceCount -Top 1 | Out-Null
# Guest
Get-MgUser -Filter "UserType eq 'guest'" -ConsistencyLevel eventual -CountVariable guestCount -Top 1 | Out-Null
# Enabled
Get-MgUser -Filter "accountEnabled eq true" -ConsistencyLevel eventual -CountVariable enabledCount -Top 1 | Out-Null
# Disabled
Get-MgUser -Filter "accountEnabled eq false" -ConsistencyLevel eventual -CountVariable disabledCount -Top 1 | Out-Null
# Stale accounts. Get-MgUser cannot filter on SignInActivity, so need to get users and increase counter
$inactiveCount = 0

# Stream users with signInActivity
Get-MgUser -All -Property "id,userPrincipalName,createdDateTime,signInActivity" | ForEach-Object {
    $created = [datetime]$_.CreatedDateTime
    $lastSuccessful = $_.SignInActivity.LastSuccessfulSignInDateTime

    # Only consider users created before the same threshold
    if ($created -lt $thresholdDate) {
        # Check if never signed in OR last successful sign-in older than 1 year
        if (-not $lastSuccessful -or [datetime]$lastSuccessful -lt $thresholdDate) {
            $inactiveCount++
        }
    }
}

Write-LogInfo("Getting privileged user count")

$activeAssignments   = Get-MgRoleManagementDirectoryRoleAssignment -All:$true
$eligibleAssignments = Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance -All:$true
$allAssignments      = $activeAssignments + $eligibleAssignments

# Prepare hashset for unique user IDs
$uniqueUsers = [System.Collections.Generic.HashSet[string]]::new()

foreach ($assignment in $allAssignments) {
    $principalId = $assignment.PrincipalId

    # Try user
    $user = Get-MgUser -UserId $principalId -ErrorAction SilentlyContinue
    if ($user) {
        Write-Output "Found USER - $($user.DisplayName)"
        $uniqueUsers.Add($user.Id) | Out-Null
        continue
    }

    # Try group
    $group = Get-MgGroup -GroupId $principalId -ErrorAction SilentlyContinue
    if ($group) {
        Write-Output "Found GROUP - $($group.DisplayName)"
        # Expand group members
        $members = Get-MgGroupMember -GroupId $group.Id -All:$true
        Write-Output "Found $($members.Count) members"
        foreach ($member in $members) {
            if ($member.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.user') {
                $uniqueUsers.Add($member.Id) | Out-Null
            }
        }
        continue
    }

    # Ignore service principals (no users)
}

Write-LogInfo("Total unique users with active or eligible roles (direct or via group): $($uniqueUsers.Count)")

$statsObject = [PSCustomObject]@{
    TimeGenerated         = $timeStamp
    TotalAccounts         = $allCount
    TotalServiceAccounts  = $serviceCount
    TotalGuests           = $guestCount
    TotalEnabledAccounts  = $enabledCount
    TotalDisabledAccounts = $disabledCount
    NotUsedForAYear       = $inactiveCount
    PrivilegedCount       = $uniqueUsers.Count
}

$statsObject

# Convert the stats into JSON format so we can send it to Log Analytics
Write-LogInfo("Convert user info to JSON")
$statsObjectJSON = ConvertTo-Json @($statsObject)

Write-LogInfo("Post data to Log Analytics")
try {PostLogAnalyticsData -logBody $statsObjectJSON -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName}
catch {
    Write-LogInfo("Failed to post to Log Analytics, sending email notification")
    Write-LogInfo("Send email notification")
    $table = $statsObject | ConvertTo-Html | Out-String
$style = @"
<style>
    table { border-collapse: collapse; width: 100%; font-family: Arial, sans-serif; font-size: 10px; }
    th, td { border: 1px solid #dddddd; text-align: left; padding: 8px; }
    th { background-color: #f2f2f2; }
</style>
"@

    $body = $style + $table
    $tenantName = Get-MgOrganization

    # Create the parameter sets
    $params = @{
        message = @{
            subject = "$($tenantName.DisplayName) - User info failed to run"
            body = @{
                contentType = "Html"
                content = "Dear IDAM Team,<br>Automation failed to run User info metrics.<br>Please investigate in the $($tenantName.DisplayName) tenant.<br>Below are the stats from this run: $body"
            }
            toRecipients = @(
                @{
                    emailAddress = @{
                        address = "$mailRecipient"
                    }
                }
            )
        }
        saveToSentItems = "false"
    }

    # Send the email
    Send-MgUserMail -UserId $mailSender -BodyParameter $params
}

Write-LogInfo("Script execution finished")
