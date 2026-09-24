<#
    .SYNOPSIS
    A script to retrieve MFA statistics and post to Log Analytics
     
    .DESCRIPTION
    Leverage Microsoft Graph API and PowerShell to fetch MFA registration detail, split these with a few math operations and post to Log Analytics.
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

# --- Start Functions
function Write-LogInfo($logEntry) {
    Write-Output "$(get-date -Format "yyyy-MM-dd HH:mm:ss K") - $($logEntry)"
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

# --- Start Script Execution
Write-LogInfo("Script execution started")

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

# --> Script Functions

function Invoke-Fido2UserBatch {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateCount(1, 20)]
        [object[]]$Users,

        [Parameter(Mandatory)]
        [System.Collections.Generic.HashSet[guid]]$AllowedAaguids,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.HashSet[string]]$BioUserIds,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.HashSet[string]]$HardwareKeyUserIds
    )

    # Keep request IDs stable: Graph can return subresponses in any order.
    $states = @(
        for ($index = 0; $index -lt $Users.Count; $index++) {
            [pscustomobject]@{
                Id      = [string]($index + 1)
                User    = $Users[$index]
                Url     = '/users/{0}/authentication/fido2Methods' -f [uri]::EscapeDataString($Users[$index].Id)
                Retries = 0
                Keys    = [System.Collections.Generic.List[object]]::new()
            }
        }
    )
    $pending = $states
    while ($pending.Count -gt 0) {
        $requests = @($pending | ForEach-Object { @{ id = $_.Id; method = 'GET'; url = $_.Url } })
        $body = @{ requests = $requests } | ConvertTo-Json -Depth 6 -Compress
        # SDK handles outer HTTP failures; HTTP 200 can still contain failed subrequests.
        $batch = Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/$batch' -Body $body -ContentType 'application/json' -OutputType PSObject -ErrorAction Stop
        $byId = @{}
        foreach ($response in $batch.responses) {
            $id = [string]$response.id
            if ($byId.ContainsKey($id)) { throw "Duplicate batch response ID '$id'." }
            $byId[$id] = $response
        }
        $next = [System.Collections.Generic.List[object]]::new()
        $delaySeconds = 0.0
        foreach ($state in $pending) {
            if (-not $byId.ContainsKey($state.Id)) {
                throw "Missing batch response for user '$($state.User.Id)'."
            }
            $response = $byId[$state.Id]
            $status = [int]$response.status
            if ($status -eq 200) {
                if ($null -eq $response.body.value) {
                    throw "Missing FIDO2 method collection for user '$($state.User.Id)'."
                }
                foreach ($key in $response.body.value) {
                    # Count users, not keys, and do not depend on the AAGUID allowlist.
                    if ($key.model -eq 'YubiKey Bio Series - FIDO Edition') {
                        [void]$BioUserIds.Add([string]$state.User.Id)
                    }
                    $keyAaguid = [guid]::Empty
                    if ([guid]::TryParse([string]$key.aaGuid, [ref]$keyAaguid) -and $AllowedAaguids.Contains($keyAaguid)) {
                        $state.Keys.Add($key)
                    }
                }
                $nextLink = $response.body.'@odata.nextLink'
                if ($nextLink) {
                    # Batch URLs must be relative to the Graph API version.
                    $pageUri = [uri]$nextLink
                    if (-not $pageUri.IsAbsoluteUri -or $pageUri.Scheme -ne 'https' -or
                        $pageUri.Host -ne 'graph.microsoft.com' -or -not $pageUri.AbsolutePath.StartsWith('/v1.0/')) {
                        throw "Unexpected Graph pagination URL for user '$($state.User.Id)'."
                    }
                    $state.Url = $pageUri.PathAndQuery.Substring('/v1.0'.Length)
                    $state.Retries = 0
                    $next.Add($state)
                }
            }
            elseif ($status -in 429, 503, 504 -and $state.Retries -lt 5) {
                $state.Retries++
                $retryDelay = [math]::Pow(2, $state.Retries)
                $retryAfter = [string]$response.headers.'Retry-After'
                $seconds = 0.0
                $retryDate = [DateTimeOffset]::MinValue
                if ([double]::TryParse($retryAfter, [ref]$seconds)) {
                    $retryDelay = [math]::Max($retryDelay, $seconds)
                }
                elseif ([DateTimeOffset]::TryParse($retryAfter, [ref]$retryDate)) {
                    $retryDelay = [math]::Max($retryDelay, ($retryDate - [DateTimeOffset]::UtcNow).TotalSeconds)
                }
                $delaySeconds = [math]::Max($delaySeconds, $retryDelay)
                $next.Add($state)
                Write-Verbose "Retry $($state.Retries)/5 for user '$($state.User.Id)' after HTTP $status."
            }
            else {
                throw "FIDO2 lookup failed for user '$($state.User.Id)': HTTP $status, $($response.body.error.code) $($response.body.error.message)"
            }
        }
        $pending = @($next.ToArray())
        if ($pending.Count -gt 0 -and $delaySeconds -gt 0) {
            Start-Sleep -Seconds ([math]::Ceiling($delaySeconds))
        }
    }

    foreach ($state in $states) {
        if ($state.Keys.Count -gt 0) {
            [void]$HardwareKeyUserIds.Add([string]$state.User.Id)
        }
    }
}

function Get-GroupOverlapPercentage {
    param ([int]$OverlapCount)
    if ($groupUserIds.Count -gt 0) {
        return [math]::Round(100.0 * $OverlapCount / $groupUserIds.Count, 2)
    }
    return $null
}

# <-- Script Functions

# --> Functional Code Starts

$hardwareKeyAaguids = @(
    '4c0cf95d-2f40-43b5-ba42-4c83a11c04ba',
    'd8522d9f-575b-4866-88a9-ba99fa02f35b',
    'dd86a2da-86a0-4cbe-b462-4bd31f57bc6f',
    '7409272d-1ff9-4e10-9fc9-ac0019c124fd'
)

# Fail before authentication rather than returning a misleading empty report.
if ($hardwareKeyAaguids.Count -eq 0) {
    throw 'Populate $hardwareKeyAaguids with your hardware security-key AAGUIDs before running this script.'
}
$hardwareKeyAaguidSet = [System.Collections.Generic.HashSet[guid]]::new()
foreach ($aaguid in $hardwareKeyAaguids) {
    $parsedAaguid = [guid]::Empty
    if (-not [guid]::TryParse($aaguid, [ref]$parsedAaguid) -or $parsedAaguid -eq [guid]::Empty) {
        throw "Invalid hardware-key AAGUID: '$aaguid'. Supply a non-zero GUID."
    }
    [void]$hardwareKeyAaguidSet.Add($parsedAaguid)
}

$groupId = '9a822f75-6b16-4a55-8f89-d2a044a8033f' #MOJO-Prison-Users-PoC-FIDO2-Registration
$groupUserIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$bioUserIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$hardwareKeyUserIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
# Direct user membership only; exclude groups, devices and service principals.
# Read membership first so permission failures occur before emitting user output.
$nextGroupLink = 'https://graph.microsoft.com/v1.0/groups/{0}/members/microsoft.graph.user?$select=id&$top=999&$count=true' -f $groupId
while ($nextGroupLink) {
    $pageUri = [uri]$nextGroupLink
    if (-not $pageUri.IsAbsoluteUri -or $pageUri.Scheme -ne 'https' -or
        $pageUri.Host -ne 'graph.microsoft.com' -or -not $pageUri.AbsolutePath.StartsWith("/v1.0/groups/$groupId/members")) {
        throw 'Unexpected Graph group-membership pagination URL.'
    }
    $page = Invoke-MgGraphRequest -Method GET -Uri $nextGroupLink -Headers @{ ConsistencyLevel = 'eventual' } -OutputType PSObject -ErrorAction Stop
    if ($null -eq $page.value) {
        throw 'Graph did not return a group-membership collection.'
    }
    foreach ($member in $page.value) {
        if ([string]::IsNullOrWhiteSpace($member.id)) {
            throw 'A group member has no ID; cannot reliably calculate membership counts.'
        }
        [void]$groupUserIds.Add([string]$member.id)
    }
    $nextGroupLink = $page.'@odata.nextLink'
}

# Current reports use passKeyDeviceBound; include the legacy fido2 label too.
# Do not filter on isPasswordlessCapable: policy can disallow a registered key.
$filter = "methodsRegistered/any(m:m eq 'passKeyDeviceBound') or methodsRegistered/any(m:m eq 'fido2')"
$excludedUpnSuffix = '@JusticeUK.onmicrosoft.com'

# -All follows pagination for the FILTERED report, not every tenant user.
# Buffer at most 20 candidates, rather than materialising the whole report.
$userBatch = [System.Collections.Generic.List[object]]::new()
Get-MgReportAuthenticationMethodUserRegistrationDetail -Filter $filter -All -ErrorAction Stop |
ForEach-Object {
    # endswith isn't a supported server-side filter for this report, so exclude locally.
    if ($_.UserPrincipalName -and $_.UserPrincipalName.EndsWith($excludedUpnSuffix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return
    }
    $userBatch.Add($_)
    if ($userBatch.Count -eq 20) {
        Invoke-Fido2UserBatch -Users $userBatch.ToArray() -AllowedAaguids $hardwareKeyAaguidSet -BioUserIds $bioUserIds -HardwareKeyUserIds $hardwareKeyUserIds
        $userBatch.Clear()
    }
}
if ($userBatch.Count -gt 0) {
    Invoke-Fido2UserBatch -Users $userBatch.ToArray() -AllowedAaguids $hardwareKeyAaguidSet -BioUserIds $bioUserIds -HardwareKeyUserIds $hardwareKeyUserIds
}

# Users with an allow-listed key who are also direct members of the group.
$groupHardwareKeyCount = @($hardwareKeyUserIds | Where-Object { $groupUserIds.Contains($_) }).Count
# Users with the Bio Series model who are also direct members of the group.
$groupBioCount = @($bioUserIds | Where-Object { $groupUserIds.Contains($_) }).Count
# Emit only after all membership and method pages have completed successfully.

$statsObject = [pscustomobject]@{
    # Ingestion timestamp for Log Analytics, not the report's own refresh time.
    TimeGenerated                   = Get-Date -Format o
    # Denominator for both percentages; includes disabled users, excludes nested members.
    SecurityGroupDirectUserMembers  = $groupUserIds.Count
    # Tenant-wide unique users with a key matching $hardwareKeyAaguids, regardless of group membership.
    HardwareKeyUsers                = $hardwareKeyUserIds.Count
    # Of the group's direct members, how many have an allow-listed hardware key.
    SecurityGroupHardwareKeyUsers   = $groupHardwareKeyCount
    # SecurityGroupHardwareKeyUsers as a percentage of SecurityGroupDirectUserMembers; $null if the group is empty.
    SecurityGroupHardwareKeyPercent = Get-GroupOverlapPercentage $groupHardwareKeyCount
    # Tenant-wide unique users with model 'YubiKey Bio Series - FIDO Edition', independent of the AAGUID allowlist.
    BioKeyUsers                     = $bioUserIds.Count
    # Of the group's direct members, how many have that Bio Series model.
    SecurityGroupBioKeyUsers        = $groupBioCount
    # SecurityGroupBioKeyUsers as a percentage of SecurityGroupDirectUserMembers; $null if the group is empty.
    SecurityGroupBioKeyPercent      = Get-GroupOverlapPercentage $groupBioCount
}
$statsObject


# <-- Functional Code Ends

# Convert the list of each Certificates & secrets for each App Registration into JSON format so we can send it to Log Analytics
Write-LogInfo("Convert MFA data to JSON")
$statsObjectJSON = ConvertTo-Json @($statsObject)

Write-LogInfo("Post data to Log Analytics")
try { PostLogAnalyticsData -logBody $statsObjectJSON -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName }
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
        message         = @{
            subject      = "$($tenantName.DisplayName) - FIDO2 stats failed to run"
            body         = @{
                contentType = "Html"
                content     = "Dear IDAM Team,<br>Automation failed to run FIDO2 metrics.<br>Please investigate in the $($tenantName.DisplayName) tenant.<br>Below are the stats from this run: $body"
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
