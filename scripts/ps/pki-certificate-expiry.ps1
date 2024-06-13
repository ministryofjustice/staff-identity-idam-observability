<#
DESCRIPTION: Process all PKI Certificates and their expiries
#>
param (
    [string]$url,
    [string]$caId,
    [string]$certificateThumbprint
)

function Run()
{   
    param (
        [Parameter(Mandatory=$true)][string]$url,
        [Parameter(Mandatory=$true)][string]$caId,
        [Parameter(Mandatory=$true)][string]$certificateThumbprint
        )

        $IsMorePages = $true
        $nextPageIndex
        $serialNumbers = @()
        
        # Get list of all certificates from start date recording serialNumbers
        while ($IsMorePages) {
            if ($nextPageIndex) {
                $nextPageIndex = "&nextPageIndex=" + $nextPageIndex
            }
            $Params = @{
                Uri = "https://$url/certificate-authorities/$caId/certificate-events?preferredPageSize=50&startDate=2023-01-01T00%3A00%3A00%2B00%3A00&%24fields=-events.certificate$nextPageIndex"
                Method = "Get"
                ContentType = "application/json"
            }
            $Response = Invoke-RestMethod @Params -CertificateThumbprint $certificateThumbprint -SkipCertificateCheck
        
            if ($Response) {
                $Results = $Response[0]
                $Events = $Results.events
                #$EventsCount = $Results.events.Count
                $IsMorePages = $Results.morePages
                $nextPageIndex = $Results.nextPageIndex
        
                $serialNumbers += foreach ($Event in $Events)
                {
                    $Event.serialNumber
                }
            } else {
                $IsMorePages = $false
            }
        }
        
        $serialNumbers = $serialNumbers | Select-Object -Unique
        
        #$serialNumbers | ConvertTo-Json -depth 10 | Out-File ".\serialNumbers.json"
        
        # Query each certificate by serial number and store result
        $certificateDetails = foreach ($serialNumber in $serialNumbers)
        {
            $CertDetailsParams = @{
                Uri = "https://$url/certificate-authorities/$caId/certificates/$serialNumber"
                Method = "Get"
                ContentType = "application/json"
            }
            $CertDetailsResponse = Invoke-RestMethod @CertDetailsParams -CertificateThumbprint $certificateThumbprint -SkipCertificateCheck
            
            # TODO - Just return validity, serial number and name?
            $Certificate = $CertDetailsResponse[0].certificate
            @{
                serialNumber = $serialNumber
                issuerName = $Certificate.issuerName
                validityPeriod = $Certificate.validityPeriod
                validityStart = $Certificate.validityPeriod.Split("/")[0]
                validityEnd = $Certificate.validityPeriod.Split("/")[1]
                subjectName = $Certificate.subjectName
            }    
        }
        
        # TODO - Add to Log Analytics
        #$certificateDetails | ConvertTo-Json -depth 10 | Out-File ".\certificateDetails.json"
}

Run -url $url -caId $caId -certificateThumbprint $certificateThumbprint
