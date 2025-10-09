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

function ConnectToGraph() {
    # Authenticate with the credentials object
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
}

function Run {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$MiClientId,
        [Parameter(Mandatory)]
        [string]$DcrImmutableId,
        [Parameter(Mandatory)]
        [string]$DceUri,
        [Parameter(Mandatory)]
        [string]$LogTableName
    )

    # --- Start Script Execution
    Write-LogInfo("Script execution started")

    ConnectToGraph

    $userDetails = @()
    $userDetails += CheckGuestUsersExternalSync
    $userDetails += CheckGuestUsersTemporaryEmails

    Write-LogInfo"$(([PSObject[]]($userDetails)).Count) Total Expired Guest(s) Found.")

    Write-LogInfo("Convert Guests list to JSON")
    $userDetailsJSON = ConvertTo-Json @($userDetails)

    Write-LogInfo("Post data to Log Analytics")

    GroupPostResults -postData $userDetailsJSON

    Write-LogInfo("Script execution finished")

}

if ($MyInvocation.InvocationName -eq 'process-guest-user-delete-devl.ps1' -or
    $MyInvocation.InvocationName -eq $PSCommandPath) {
    Run -MiClientId $MiClientId -DcrImmutableId $DcrImmutableId -DceUri $DceUri -LogTableName $LogTableName
}
#Run($MiClientId, $DcrImmutableId, $DceUri, $LogTableName)

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

function GetDays() {
    param (
        [Parameter(Mandatory = $true)][datetime]$date
    )
    if ($null -eq $date) {
        return 0
    }
    return ((Get-Date) - ($date) | Select-Object -ExpandProperty TotalDays) -as [int]
}

function IsToBeDeleted() {
    param (
        [Parameter(Mandatory = $true)][int]$daysSinceCreated,
        [Parameter(Mandatory = $true)][int]$daysSinceLastLogin,
        [Parameter(Mandatory = $true)][bool]$hasLoggedIn
    )
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

function GetGroupMembers() {
    param (
        [Parameter(Mandatory = $true)][string]$GroupName
    )
    $group = Get-MgGroup -Filter "displayName eq '$GroupName'"

    return Get-MgGroupMember -GroupId $group.Id
}

function GetUserDetails() {
    param (
        [Parameter(Mandatory = $true)][string]$UserId,
        [Parameter(Mandatory = $true)][string]$JobTitle
    )
    Write-LogInfo"int " + $UserId)
    $user = Get-MgUser -UserId $UserId -Property ID, DisplayName, UserPrincipalName, SignInActivity, CompanyName, JobTitle, Department, CreatedDateTime

    if ($JobTitle -eq $user.JobTitle) {

        $LastLoginDate = $user.SignInActivity.LastSignInDateTime

        $DaysInactive = GetDays -date $LastLoginDate
        $DaysSinceCreated = GetDays -date $user.CreatedDateTime

        return [PSCustomObject]@{
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

    $groupMembers = GetGroupMembers -GroupName "MoJo-External-Sync-Legal-Aid-Agency-Staff"
    $deleteType = "externalsync"
    $removal = "Removed"
    
    foreach ($member in $groupMembers) {
        Write-LogInfo"int member " + $member.DisplayName)
        $user = GetUserDetails -UserId $member.Id -JobTitle "Internal SilAS Test Account"

        $isToBeDeleted = IsToBeDeleted -daysSinceCreated $user.dayssincecreated -daysSinceLastLogin $user.daysinactive -hasLoggedIn ($null -ne $user.lastlogindate)
        
        if ($isToBeDeleted -eq $true) {
            <# try {
                Remove-MgUser -UserId $user.Id -ErrorAction Stop
            }
            catch
            {
                $removal = "$($_.Exception)"
            } #>
                    
            return [PSCustomObject]@{
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

    $groupMembers = GetGroupMembers -GroupName "External-Email-Temp-Test-Tenant-Access"
    $deleteType = "temporaryemail"
    $removal = "Removed"
    
    foreach ($member in $groupMembers) {
        $user = GetUserDetails -UserId $member.Id -JobTitle "External Email SilAS Test Account"
        
        if ($user.daysinactive -gt 30) {
            <# try {
                Remove-MgUser -UserId $user.Id -ErrorAction Stop
            }
            catch
            {
                $removal = "$($_.Exception)"
            } #>
                    
            return [PSCustomObject]@{
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

function GroupPostResults() {
    param (
        [Parameter(Mandatory = $true)][string]$postData
    )
    for ($i = 0; $i -lt $postData.Count; $i += 500) {
        $batchNumber = ([Math]::Min($i + 499, $postData.Count - 1))
        $postDataBatch = $postData[$i..$batchNumber]

        $json = $postDataBatch | ConvertTo-Json -Depth 10

        PostLogAnalyticsData -logBody $json -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName
        
        Write-LogInfo("Sent batch from $($i+1) to $($batchNumber+1))")   
    }
}

