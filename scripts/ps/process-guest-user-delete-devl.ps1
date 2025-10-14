<#
    .SYNOPSIS
    A script to remove Guest users from the tenant.
     
    .DESCRIPTION
    Used for the DEV environments, this helps ensure our tenants are in a healthy and uncluttered position.
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

function GetDays($date) {
    if ($null -eq $date) {
        return 0
    }
    return ((Get-Date) - ($date) | Select-Object -ExpandProperty TotalDays) -as [int]
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

function GetGroupMembers($GroupName) {
    $group = Get-MgGroup -Filter "displayName eq '$GroupName'"

    return Get-MgGroupMember -GroupId $group.Id
}

function GetUserDetails($UserId, $JobTitle) {
    $user = Get-MgUser -UserId $member.Id -Property ID, DisplayName, UserPrincipalName, SignInActivity, CompanyName, JobTitle, Department, CreatedDateTime

    if ($JobTitle -eq $user.JobTitle) {

        $LastLoginDate = $user.SignInActivity.LastSignInDateTime

        $DaysInactive = GetDays($LastLoginDate);
        $DaysSinceCreated = GetDays($user.CreatedDateTime);

        return  [PSCustomObject]@{
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
                }
    }
}

function CheckGuestUsersExternalSync() {

    $groupMembers = GetGroupMembers("MoJo-External-Sync-Legal-Aid-Agency-Staff")
    $deleteType = "externalsync"
    $removal = "Removed"
    
    foreach ($member in $groupMembers) {
        $user = GetUserDetails($member.Id, "Internal SilAS Test Account")

        $isToBeDeleted = IsToBeDeleted($user.dayssincecreated, $user.daysinactive, ($null -ne $user.lastlogindate))
        
        if ($isToBeDeleted -eq $true) {
            <# try {
                Remove-MgUser -UserId $user.Id -ErrorAction Stop
            }
            catch
            {
                $removal = "$($_.Exception)"
            } #>
                    
            $userDetails += [PSCustomObject]@{
                id                = $user.id
                displayname       = $user.displayname
                userprincipalname = $user.userprincipalname
                createddatetime   = $user.createddatetime
                dayssincecreated  = $user.dayssincecreated
                lastlogindate     = $user.lastlogindate
                daysinactive      = $user.daysinactive
                companyname       = $user.companyname
                jobtitle          = $user.jobtitle
                department        = $user.department
                cleanup           = $removal
                deletetype        = $deleteType
                TimeGenerated     = $ExpiredCred.TimeGenerated
            }
        }
    }
}

function CheckGuestUsersTemporaryEmails() {

    $groupMembers = GetGroupMembers("External-Email-Temp-Test-Tenant-Access")
    $deleteType = "temporaryemail"
    $removal = "Removed"
    
    foreach ($member in $groupMembers) {
        $user = GetUserDetails($member.Id, "External Email SilAS Test Account")
        
        if ($user.daysinactive -gt 14) {
            <# try {
                Remove-MgUser -UserId $user.Id -ErrorAction Stop
            }
            catch
            {
                $removal = "$($_.Exception)"
            } #>
                    
            $userDetails += [PSCustomObject]@{
                id                = $user.id
                displayname       = $user.displayname
                userprincipalname = $user.userprincipalname
                createddatetime   = $user.createddatetime
                dayssincecreated  = $user.dayssincecreated
                lastlogindate     = $user.lastlogindate
                daysinactive      = $user.daysinactive
                companyname       = $user.companyname
                jobtitle          = $user.jobtitle
                department        = $user.department
                cleanup           = $removal
                deletetype        = $deleteType
                TimeGenerated     = $ExpiredCred.TimeGenerated
            }
        }
    }
}

CheckGuestUsersExternalSync
CheckGuestUsersTemporaryEmails

Write-LogInfo("$(([PSObject[]]($userDetails)).Count) Total Expired Geuest Found.")

Write-LogInfo("Convert Guests list to JSON")
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
