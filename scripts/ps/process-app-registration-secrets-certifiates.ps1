<#
DESCRIPTION: Process app registration secrets and certifiates
#>
param (
    [string]$MiClientId,
    [string]$DcrImmutableId,
    [string]$DceUri,
    [string]$LogTableName
)

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


# Authenticate with the credentials object
try 
{
    # Ensures you do not inherit an AzContext in your runbook
    Disable-AzContextAutosave -Scope Process

    # Connect to Azure with user-assigned managed identity
    Connect-AzAccount -Identity -AccountId $MiClientId

    $context = (Connect-AzAccount -Identity -AccountId $MiClientId).context
    $context = Set-AzContext -SubscriptionName $context.Subscription -DefaultProfile $context
    write-output "context is $context"
} 
catch 
{
  write-error "$($_.Exception)"
  throw "$($_.Exception)"
}

# Get the full list of Azure AD App Registrations
$applications = Get-AzADApplication

write-output ([PSObject[]]($applications)).Count

# Create an array named appWithCredentials
$appWithCredentials = @()

# Retrieve the list of applications and sort them by DisplayName
$appWithCredentials += $applications | Sort-Object -Property DisplayName | ForEach-Object {
    # Assign the variable application with the follow list of properties
    $application = $_

    # Use the Get-AzADAppCredential cmdlet to get the Certificates & secrets configured (this returns StartDate, EndDate, KeyID, Type, Usage, CustomKeyIdentifier)
    # Populate the array with the DisplayName, ObjectId, ApplicationId, KeyId, Type, StartDate and EndDate of each Certificates & secrets for each App Registration
    $application | Get-AzADAppCredential -ErrorAction SilentlyContinue | Select-Object `
    -Property @{Name='displayname'; Expression={$application.DisplayName}}, `
    @{Name='objectid'; Expression={$application.Id}}, `
    @{Name='applicationid'; Expression={$application.AppId}}, `
    @{Name='keyid'; Expression={$_.KeyId}}, `
    @{Name='eventtype'; Expression={if($_.Type -ne $null) {'Certificate'} else {'Secret'}}},`
    @{Name='startdate'; Expression={$_.StartDateTime -as [datetime]}},`
    @{Name='enddate'; Expression={$_.EndDateTime -as [datetime]}}                                                                                                                                                                                                                                                               
  }

# With the $application array populated with the Certificates & secrets and its App Registration, proceed to calculate and add the fields to each record in the array:
# Expiration of the certificate or secret - Valid or Expired
# Add the timestamp used to calculate the validity
# The days until the certificate or secret expires

$timeStamp = Get-Date -format o
$today = (Get-Date).ToUniversalTime()

$appWithCredentials | Sort-Object EndDate | ForEach-Object {
  # First if catches certificates & secrets that are expired
        if($_.EndDate -lt $today) {
            $days= ($_.EndDate-$Today).Days
            $_ | Add-Member -MemberType NoteProperty -Name 'status' -Value 'Expired'
            $_ | Add-Member -MemberType NoteProperty -Name 'TimeGenerated' -Value "$timestamp"
            $_ | Add-Member -MemberType NoteProperty -Name 'daystoexpiration' -Value $days
            # Second if catches certificates & secrets that are still valid
        }  else {
            $days= ($_.EndDate-$Today).Days
            $_ | Add-Member -MemberType NoteProperty -Name 'status' -Value 'Valid'
            $_ | Add-Member -MemberType NoteProperty -Name 'TimeGenerated' -Value "$timestamp"
            $_ | Add-Member -MemberType NoteProperty -Name 'daystoexpiration' -Value $days
        }
}

# Convert the list of each Certificates & secrets for each App Registration into JSON format so we can send it to Log Analytics
$appWithCredentialsJSON = $appWithCredentials | convertto-json

PostLogAnalyticsData -logBody $appWithCredentialsJSON -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName
