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

#Connect-Entra -Scopes "Application.Read.All"

$expirationThreshold = (Get-Date)

# App Registrations
$applicationList = Get-EntraApplication -All
$clientSecretApps = $applicationList | Where-Object {$_.passwordCredentials}
$clientCertApps = $applicationList | Where-Object {$_.keyCredentials}
$appRegistrationsWithNoOwners = 0

foreach ($application in $applicationList) {
    $owners = Get-MgApplicationOwner -ApplicationId $application.Id
    if ($owners.Count -eq 0) {
        $appRegistrationsWithNoOwners = $appRegistrationsWithNoOwners + 1
    }
}

$appRegistrationsWithExpiredSecrets = $clientSecretApps.PasswordCredentials |Where-Object { $_.EndDate -le $expirationThreshold } | Measure-Object
$appRegistrationsWithExpiredKeys = $clientCertApps.KeyCredentials |Where-Object { $_.EndDate -le $expirationThreshold } | Measure-Object

# Service Principals / EnterpriseApps 
$EnterpriseApps = Get-EntraServicePrincipal -All:$true | ? {$_.Tags -eq "WindowsAzureActiveDirectoryIntegratedApp"}

$EnterpriseAppsWithExpiredSecrets = ($EnterpriseApps.PasswordCredentials | Where-Object { $_.EndDateTime -le $expirationThreshold } | Measure-Object).count
$EnterpriseAppsWithExpiredKeys = ($EnterpriseApps.KeyCredentials | Where-Object { $_.EndDateTime -le $expirationThreshold } | Measure-Object).count
$EnterpriseAppsWithNoOwners = 0

foreach ($EnterpriseApp in $EnterpriseApps) {
    $owners = Get-MgServicePrincipalOwner -ServicePrincipalId $EnterpriseApp.Id
    if ($owners.Count -eq 0) {
        $EnterpriseAppsWithNoOwners = $EnterpriseAppsWithNoOwners + 1
    }
}

$statsObject = [PSCustomObject]@{
    "TotalAppRegistrations" = $applicationList.Count
    "AppRegistrationsWithNoOwners" = $appRegistrationsWithNoOwners
    "AppRegistrationsWithExpiredCredentials" = $appRegistrationsWithExpiredSecrets.Count + $appRegistrationsWithExpiredKeys.Count
    "TotalEnterpriseApps" = $EnterpriseApps.count
    "EnterpriseAppsWithNoOwners" = $EnterpriseAppsWithNoOwners
    "EnterpriseAppsWithExpiredPasswords" = $EnterpriseAppsWithExpiredSecrets
    "EnterpriseAppsWithExpiredKeys" = $EnterpriseAppsWithExpiredKeys
    "EnterpriseAppsWithExpiredCredentialsTotal" = $EnterpriseAppsWithExpiredSecrets + $EnterpriseAppsWithExpiredKeys
}
$statsObject

# Convert the results into JSON format so we can send it to Log Analytics
Write-LogInfo("Convert data to JSON")
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
            subject = "$($tenantName.DisplayName) - App stats failed to run"
            body = @{
                contentType = "Html"
                content = "Dear IDAM Team,<br>Automation failed to run App metrics.<br>Please investigate in the $($tenantName.DisplayName) tenant.<br>Below are the stats from this run: $body"
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
