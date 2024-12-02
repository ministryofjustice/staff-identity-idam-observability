<#
    .SYNOPSIS
    A script to send a list of credentials with their expiry to Log Analytics
    
    .DESCRIPTION
    Leverage Microsoft Graph API and PowerShell to fetch a list of credentials (Certificates and Secrets) that are on Application Registrations, work out their expiry details, owners and send the data to Log Analytics..
#>
param (
    [string]$MiClientId,
    [string]$DcrImmutableId,
    [string]$DceUri,
    [string]$LogTableName
)

# --- Start variables
$timeStamp = Get-Date -format o
$excludedUpns = @("Matthew.White1@justice.gov.uk", "John.Dryden@justice.gov.uk")

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

function ApplicationOwnersAsCsv($applicationId) {
    $owners = Get-MgApplicationOwnerAsUser -ApplicationId $applicationId -Property UserPrincipalName | Select-Object UserPrincipalName

    $cleanedOwners = foreach ($owner in $owners){
        if ($owner.UserPrincipalName | Where-Object { $_ -notin $excludedUpns }) {
            if ($owner.UserPrincipalName | Where-Object { -not $_.EndsWith("@JusticeUK.onmicrosoft.com") }) {
                [PSCustomObject]@{
                    UserPrincipalName         = $owner.UserPrincipalName
                }
            }
        }
    }

    $cleanedOwners = $cleanedOwners | ConvertTo-Csv -NoTypeInformation    

    return ($cleanedOwners -join "," -replace ('"', '') -replace ('UserPrincipalName,', ''))
}

function GenerateCredentials() {

    #Write-LogInfo("Fetch all Application Registrations")

    $applications = Get-MgApplication -All | Select-Object AppId, DisplayName, PasswordCredentials, KeyCredentials, Id, Owners | Sort-Object -Property DisplayName
    #Write-LogInfo("$(([PSObject[]]($applications)).Count) Applications Found.")

    $CertificateApps  = $applications | Where-Object {$_.keyCredentials}
    #Write-LogInfo("$(([PSObject[]]($CertificateApps)).Count) Applications with Certificates Found.")

    $ClientSecretApps = $applications | Where-Object {$_.passwordCredentials}
    #Write-LogInfo("$(([PSObject[]]($ClientSecretApps)).Count) Applications with Secrets Found.")

    
    $CertApp = foreach ($App in $CertificateApps) {
        foreach ($Cert in $App.KeyCredentials) {
            $applicationOwners = ApplicationOwnersAsCsv($App.Id)

            $daysToExpiry = (($Cert.EndDateTime) - (Get-Date) | Select-Object -ExpandProperty TotalDays) -as [int]
            $expiredState = "Valid"
            if($daysToExpiry -lt 1) {
                $expiredState = "Expired"
            }
            [PSCustomObject]@{
                displayname         = $App.DisplayName
                applicationid       = $App.AppId
                eventtype           = 'Certificate'
                startdate           = $Cert.StartDateTime
                enddate             = $Cert.EndDateTime
                daystoexpiration    = $daysToExpiry
                objectid            = $App.Id
                keyid               = $Cert.KeyId
                description         = $Cert.DisplayName
                TimeGenerated       = $timeStamp
                status              = $expiredState
                owners              = $applicationOwners
            }
        }
    }
    
    #Write-LogInfo("$(([PSObject[]]($CertApp)).Count) Certificates Found.")
    
    $SecretApp = foreach ($App in $ClientSecretApps){
        foreach ($Secret in $App.PasswordCredentials) {
            $applicationOwners = ApplicationOwnersAsCsv($App.Id)

            $daysToExpiry = (($Secret.EndDateTime) - (Get-Date) | Select-Object -ExpandProperty TotalDays) -as [int]
            $expiredState = "Valid"
            if($daysToExpiry -lt 1) {
                $expiredState = "Expired"
            }
            [PSCustomObject]@{
                displayname         = $App.DisplayName
                applicationid       = $App.AppId
                eventtype           = 'Secret'
                startdate           = $Secret.StartDateTime
                enddate             = $Secret.EndDateTime
                daystoexpiration    = $daysToExpiry
                objectid            = $App.Id
                keyid               = $Secret.KeyId
                description         = $Secret.DisplayName
                TimeGenerated       = $timeStamp
                status              = $expiredState
                owners              = $applicationOwners
            }
        }
    }
    
    #Write-LogInfo("$(([PSObject[]]($SecretApp)).Count) Secrets Found.")
    $SecretApp + $CertApp
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

$appWithCredentials = GenerateCredentials

Write-LogInfo("$(([PSObject[]]($appWithCredentials)).Count) Total Credentials Found.")

# Convert the list of each Certificates & secrets for each App Registration into JSON format so we can send it to Log Analytics
Write-LogInfo("Convert Credentials list to JSON")
$appWithCredentialsJSON = $appWithCredentials | ConvertTo-Json

Write-LogInfo("Post data to Log Analytics")
PostLogAnalyticsData -logBody $appWithCredentialsJSON -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName

Write-LogInfo("Script execution finished")
