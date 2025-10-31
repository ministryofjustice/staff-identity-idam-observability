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

    Connect-MgGraph -Identity -ClientId $MiClientId
    Write-LogInfo("Context is $context")
} 
catch 
{
  write-error "$($_.Exception)"
  throw "$($_.Exception)"
}

# Get MFA report
$AllMFA = Get-MgReportAuthenticationMethodUserRegistrationDetail -All
# Trim to non-guests
$users = $AllMFA | Where-Object UserType -EQ "member"

# stats
$total = $users.Count

$enrolled = $users | Where-Object IsMfaRegistered -EQ $True | Measure-Object
$authenticator = $users | Where-Object MethodsRegistered -Like *Authenticator* | Measure-Object # or 'softwareOneTimePasscode' ?
$phone = $users | Where-Object MethodsRegistered -Like *phone* | Measure-Object
$hardware = $users | Where-Object MethodsRegistered -Like *hardwareOneTimePasscode* | Measure-Object
$whfb = $users | Where-Object MethodsRegistered -Like *windowsHelloForBusiness* | Measure-Object
# Count methods registered per user
$0 = 0
$1 = 0
$2 = 0
$3 = 0
$4plus = 0
foreach ($user in $users) {
    $count = $user.MethodsRegistered.Count
    if ($count -eq "0") {$0++}
    elseif ($count -eq "1") {$1++}
    elseif ($count -eq "2") {$2++}
    elseif ($count -eq "3") {$3++ }
    elseif ($count -ge "4") {$4plus++}
}

$statsObject = [PSCustomObject]@{
        TimeGenerated             = $timeStamp
        TotalEnabledNonGuestUsers = $total
        MFAenrolled               = $enrolled.count
        MFAenrolledPercent        = [math]::Round($enrolled.Count/$total*100,2)
        PhoneCount                = $phone.Count
        PhoneMFAPercent           = [math]::Round($phone.Count/$total*100,2)
        AuthenticatorCount        = $authenticator.Count
        AuthenticatorMFAPercent   = [math]::Round($authenticator.Count/$total*100,2)
        HardwareCount             = $hardware.Count
        HardwareMFAPercent        = [math]::Round($hardware.Count/$total*100,2)
        WindowsHelloCount         = $whfb.Count
        WindowsHelloMFAPercent    = [math]::Round($whfb.Count/$total*100,2)
        ZeroMethodsRegistered     = $0
        OneMethodRegistered       = $1
        TwoMethodsRegistered      = $2
        ThreeMethodsRegistered    = $3
        FourPlusMethodsRegistered = $4plus
    }
$statsObject

# Convert the list of each Certificates & secrets for each App Registration into JSON format so we can send it to Log Analytics
Write-LogInfo("Convert MFA data to JSON")
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
            subject = "$($tenantName.DisplayName) - MFA stats failed to run"
            body = @{
                contentType = "Html"
                content = "Dear IDAM Team,<br>Automation failed to run MFA metrics.<br>Please investigate in the $($tenantName.DisplayName) tenant.<br>Below are the stats from this run: $body"
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
