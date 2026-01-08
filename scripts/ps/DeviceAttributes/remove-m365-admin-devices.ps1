<#
    DESCRIPTION:    Uses graph to remove an Entra ID attribute to all device objects in an Entra ID Group
    NOTES:          Believe this is not used looking at run history, but saving in git for archive purposes
    AUTHOR:         Stewart Young
    DATE:           16-04-2024
#>

#region Initialize
# Fetching all variables from the Automation Account (do not change this)
$ClientID = Get-AutomationVariable -Name 'ClientID'
$ClientSecret = Get-AutomationVariable -Name 'ClientSecret'
$TenantID = Get-AutomationVariable -Name 'TenantID'
$GroupID = Get-AutomationVariable -Name 'GroupIDRemove'
# The body of the request to remove attribute
$body = @{
    extensionAttributes = @{
        extensionAttribute1 = ""
    }
} | ConvertTo-Json
#endregion Initialize

#region Functions
function Get-MSGraphAppToken{
    <#
    .SYNOPSIS
        Get app based authentication token for MS Graph and return Header for authentication.
    .DESCRIPTION
        Get app based authentication token for MS Graph and return Header for authentication
    .PARAMETER TenantID
        Azure AD Tenant ID for authentication
    .PARAMETER ClientID
        Azure AD App Client ID 
    .PARAMETER ClientSecret            
        Client Secret for Azure AD Authentication 
    .NOTES
        Author:      Jan Ketil Skanke 
        Contact:     @JankeSkanke
        Created:     2020-03-29
        Updated:     2020-03-29
        Version history:
        1.0.0 - (2020-03-29) Function created
    #>    
[CmdletBinding()]
	param (
		[parameter(Mandatory = $true, HelpMessage = "Your Azure AD Directory ID should be provided")]
		[ValidateNotNullOrEmpty()]
		[string]$TenantID,
		[parameter(Mandatory = $true, HelpMessage = "Application ID for an Azure AD application")]
		[ValidateNotNullOrEmpty()]
		[string]$ClientID,
		[parameter(Mandatory = $true, HelpMessage = "Azure AD Application Client Secret.")]
		[ValidateNotNullOrEmpty()]
		[string]$ClientSecret
	    )
Process {
    $ErrorActionPreference = "Stop"
       
    # Construct URI
    $uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

    # Construct Body
    $body = @{
        client_id     = $clientId
        scope         = "https://graph.microsoft.com/.default"
        client_secret = $clientSecret
        grant_type    = "client_credentials"
        }
    
    try {
        $MyTokenRequest = Invoke-WebRequest -Method Post -Uri $uri -ContentType "application/x-www-form-urlencoded" -Body $body -UseBasicParsing
        $MyToken =($MyTokenRequest.Content | ConvertFrom-Json).access_token
            If(!$MyToken){
                Write-Warning "Failed to get Graph API access token!"
                Exit 1
            }   
        $MyHeader = @{"Authorization" = "Bearer $MyToken" }
        $ExpirySeconds =($MyTokenRequest.Content | ConvertFrom-Json).expires_in
        $global:TokenExpiry = (Get-Date).AddSeconds($ExpirySeconds)

       }
    catch [System.Exception] {
        Write-Warning "Failed to get Access Token, Error message: $($_.Exception.Message)"; break
    }
    return $MyHeader
    }
}#end function 
#endregion Functions

#region Script

#Get Authentication Token for MSGraph
Try
    {
        $Header = Get-MSGraphAppToken -TenantID $tenantId -ClientID $ClientID -ClientSecret $ClientSecret -ErrorAction Stop        
    }
Catch
    {
        $ErrorMessage = $_.Exception.Message
        Write-Error -Message "Connection to Graph failed with $ErrorMessage"
        Break
    }

if ($Header) 
{
    Write-Output "Connected to Microsoft Graph"
    Write-Output "Getting group members"
    $DevicesResponse = Invoke-RestMethod -Method Get -Uri "https://graph.microsoft.com/v1.0/groups/$($GroupID)/transitiveMembers" -ContentType "application/json" -Headers $Header -UseBasicParsing -ErrorAction Stop
    $Devices = $DevicesResponse.value
    $DevicesNextLink = $DevicesResponse."@odata.nextLink"

    # Get all devices in Entra group
    while ($null -ne $DevicesNextLink)
    {

        $DevicesResponse = Invoke-RestMethod -Method Get -Uri $DevicesNextLink -ContentType "application/json" -Headers $Header -ErrorAction Stop
        $DevicesNextLink = $DevicesResponse."@odata.nextLink"
        $Devices += $DevicesResponse.value

    }

    $Devices = $Devices | Where-Object {$_.'@odata.type' -eq "#microsoft.graph.device"} 
    Write-Output "$($Devices.displayName.Count) devices retrieved from group"

    # Get list of devices which have attribute set
    $WithAttribute = $Devices | Where-Object {$_.extensionAttributes -Match "MoJOAdminDevice"}

    if ($WithAttribute)
    {   
        Write-Output "$($WithAttribute.displayName.Count) devices found with attribute set"
        # Remove attribute on devices with it currently set
        foreach ($machine in $WithAttribute)
        {
            Write-Output "Removing attribute for $($machine.displayName)"
            # Make the PATCH request
            Invoke-RestMethod -Method Patch -Uri "https://graph.microsoft.com/v1.0/devices/$($machine.id)" -ContentType "application/json" -Body $body -Headers $Header -ErrorAction Stop
            Write-Output "Attribute removed for $($machine.displayName)"
            

        }

        
        Write-Output "Verifying all devices are now updated"
        # Look up graph again to check all attributes are now updated
        $DevicesResponseVerify = Invoke-RestMethod -Method Get -Uri "https://graph.microsoft.com/v1.0/groups/$($GroupID)/transitiveMembers" -ContentType "application/json" -Headers $Header -UseBasicParsing -ErrorAction Stop
        $DevicesVerify = $DevicesResponseVerify.value
        $DevicesNextLinkVerify = $DevicesResponseVerify."@odata.nextLink"

        # Get all devices in Entra group
        while ($null -ne $DevicesNextLinkVerify)
        {

            $DevicesResponseVerify = Invoke-RestMethod -Method Get -Uri $DevicesNextLink -ContentType "application/json" -Headers $Header -ErrorAction Stop
            $DevicesNextLinkVerify = $DevicesResponseVerify."@odata.nextLink"
            $DevicesVerify += $DevicesResponseVerify.value

        }

        $DevicesVerify = $DevicesVerify | Where-Object {$_.'@odata.type' -eq "#microsoft.graph.device"} 

        $WithAttributeVerify = $DevicesVerify | Where-Object {$_.extensionAttributes -Match "MoJOAdminDevice"}

        if (!($WithAttributeVerify))
        {
            Write-Output "All devices in group successfully removed attribute"
        }
        else 
        {
            Write-Output "Failed to remove attribute for all devices"
        }

    }
    else 
    {
        Write-Output "No device attributes need removed"
        Exit 
    }

    

}

#endregion Script
