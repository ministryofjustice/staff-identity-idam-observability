<#
    .SYNOPSIS
    A script that gets owners, roles and information about access packages
     
    .DESCRIPTION
    Leverage Microsoft Graph API and PowerShell to fetch a list Catalogs, Access packages and groups #>


    

#Authentication to MS Graph
param(
    [string]$MIclientId,
    [string]$DcrImmutableId,
    [string]$DceUri,
    [string]$LogTableName
)


function Write-LogInfo($logentry) {
    Write-Output "$(get-date -Format "yyyy-MM-dd HH:mm:ss K") - $($logentry)"
}

# Post data function
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

# --- Get Groups Dictionary --- Format:  ID: Displayname -- Need to get all groups as need to match it with access package resource
function Get-GroupsDictionary {
    $groupDictionary = @{}
    $groups = Get-MgBetaGroup -All -Property Id, DisplayName
    foreach ($group in $groups) {
        $groupDictionary[$group.Id] = $group.DisplayName
    }
    return $groupDictionary
}

# --- Get Access Package Resources ---
function Get-ResourcesFromAccessPackages {
    param (
        [hashtable]$GroupDictionary  # A lookup table mapping group IDs to their display names
    )
    
    # Retrieve all access package catalogs in the tenant
    $accessPackageCatalogs = Get-MgBetaEntitlementManagementAccessPackageCatalog -All

    # Initialize an empty array to store the final export data
    $exportList = @()

    # Count the total number of catalogs for progress tracking
    $totalCatalogs = $accessPackageCatalogs.Count

    # Loop through each catalog
    foreach ($catalog in $accessPackageCatalogs) {
        Write-Host "[$($accessPackageCatalogs.IndexOf($catalog) + 1)/$($totalCatalogs)][Catalog: $($catalog.DisplayName)]"

        # Get all resources associated with the current catalog
        $resources = Get-MgBetaEntitlementManagementAccessPackageCatalogAccessPackageResource -AccessPackageCatalogId $catalog.Id -ExpandProperty *

        # Get all access packages within the current catalog, including their resource role scopes
        $accessPackages = Get-MgBetaEntitlementManagementAccessPackage -CatalogId $catalog.Id -ExpandProperty AccessPackageResourceRoleScopes

        # Track how many access packages are in this catalog
        $totalAccessPackagesInCatalog = $accessPackages.count
        $counter = 1

        # Loop through each access package
        foreach ($accessPackage in $accessPackages) {
            Write-Host "`t[$counter/$($totalAccessPackagesInCatalog)][Access Package: $($accessPackage.DisplayName)]"
            $counter++

            # Extract role IDs from the resource role scopes (format is usually "<roleId>_<resourceScopeId>")
            $roleIDs = $accessPackage.AccessPackageResourceRoleScopes.Id | ForEach-Object { ($_ -split '_')[0] }

            # Loop through each role ID to find the associated group/resource
            foreach ($roleID in $roleIDs) {
                # Find the matching role object in the catalog's resources
                $roleObject = $resources.AccessPackageResourceRoles | Where-Object { $_.id -eq $roleID }

                # Validate that the role object exists and has a properly formatted OriginId
                if ($roleObject -and $roleObject.OriginId -and ($roleObject.OriginId -split '_').Count -ge 2) {
                    # Extract the group/resource ID from the OriginId (second part after splitting)
                    $matchedRole = ($roleObject.OriginId -split '_')[1]

                    # Add a new entry to the export list with catalog, access package, and group details
                    $exportList += [PSCustomObject][Ordered]@{
                        Catalog          = $catalog.DisplayName
                        CatalogID        = $catalog.id
                        AccessPackage    = $accessPackage.DisplayName
                        AccessPackageID  = $accessPackage.Id
                        GroupDisplayname = $GroupDictionary[$matchedRole]
                        GroupID          = $matchedRole
                    }
                } else {
                    # If the role object is missing or malformed, skip it and log a warning
                    Write-Warning "Skipping roleID '$roleID' due to missing or malformed OriginId"
                }
            }
        }
    }

    # Return the full list of access package resource mappings
    return $exportList
}
#Function to Get Entra Role Assignments for Access Package-Linked Groups
function Get-EntraRolesForGroups {
    param (
        [array]$GroupIDs
    )

    $eligibleRoles = Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance -All # Get all Eligible roles
    $activeRoles = Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance -All # Get all Active roles (Entra roles)
    $roleDefinitions = Get-MgRoleManagementDirectoryRoleDefinition -All # Get all active Entra role definitions (EG User administrator)

    Write-Host "Eligible roles returned: $($eligibleRoles.Count)" #Counting all Eligible roles
    Write-Host "Active roles returned: $($activeRoles.Count)" #Count all Active roles

    $results = @()
    #Iterating through each Eligiblerole
    foreach ($role in $eligibleRoles) {
        #For each role checking the principalID(which is the security object ID EG group) 
        if ($GroupIDs -contains $role.PrincipalId) {
            $roleDef = $roleDefinitions | Where-Object { $_.Id -eq $role.RoleDefinitionId }

            #Write-Host "Eligible → Group: $($role.PrincipalId), Role: $($roleDef.DisplayName)"
            #Creating custom object then addiing to to the results array
            $results += [PSCustomObject]@{
                GroupID         = $role.PrincipalId
                RoleName        = $roleDef.DisplayName
                RoleDescription = $roleDef.Description
                Scope           = $role.Scope
                AssignmentType  = "Eligible"
                RoleStatus      = "Eligible"
            }
        }
    }

    foreach ($role in $activeRoles) {
        if ($GroupIDs -contains $role.PrincipalId) {
            $roleDef = $roleDefinitions | Where-Object { $_.Id -eq $role.RoleDefinitionId }

            $roleStatus = if ($role.EndDateTime) { "Activated" } else { "Assigned" }

            #Write-Host "$roleStatus → Group: $($role.PrincipalId), Role: $($roleDef.DisplayName)"

            $results += [PSCustomObject]@{
                GroupID         = $role.PrincipalId
                RoleName        = $roleDef.DisplayName
                RoleDescription = $roleDef.Description
                Scope           = $role.Scope
                AssignmentType  = "Active"
                RoleStatus      = $roleStatus
            }
        }
    }

    return $results
}
function Get-GroupOwnersWithNames {
    param (
        [array]$GroupIDs
    )
    #Creating empty array
    $ownersList = @()

    foreach ($groupId in $GroupIDs) {
        try {
            $owners = Get-MgGroupOwner -GroupId $groupId -ErrorAction Stop

            foreach ($owner in $owners) {
                $ownerDetails = $null

                if ($owner.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.user') {
                    $ownerDetails = Get-MgUser -UserId $owner.Id -ErrorAction SilentlyContinue
                } elseif ($owner.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.servicePrincipal') {
                    $ownerDetails = Get-MgServicePrincipal -ServicePrincipalId $owner.Id -ErrorAction SilentlyContinue
                }

                $ownersList += [PSCustomObject]@{
                    GroupID   = $groupId
                    OwnerName = if ($ownerDetails) { $ownerDetails.DisplayName } else { "Unknown ($($owner.Id))" }
                    OwnerId   = $owner.Id
                }
            }
        } catch {
            Write-Warning "Failed to retrieve owners for group $groupId"
        }
    }

    return $ownersList
}

function Get-AccessReviewGroups {
    param (
        [array]$AccessPackageIDs
    )

    $reviewerGroupsList = @()
    $allReviews = Get-MgIdentityGovernanceAccessReviewDefinition

    foreach ($review in $allReviews) {
        $query = $review.Scope.AdditionalProperties["query"]
        Write-Host "Processing review: $($review.DisplayName)"
        Write-Host "Scope query: $query"

        if ($query -match "accessPackageId eq '([0-9a-fA-F-]+)'") {
            $extractedId = $matches[1]
            Write-Host "Extracted AccessPackageId: $extractedId"

            if ($AccessPackageIDs -contains $extractedId) {
                Write-Host "AccessPackageId matched. Checking reviewers..."

                if ($review.Reviewers) {
                    foreach ($reviewer in $review.Reviewers) {
                        $reviewerQuery = $reviewer.Query
                        Write-Host "Reviewer query: $reviewerQuery"

                        if ($reviewerQuery -match "/groups/([0-9a-fA-F-]+)/transitiveMembers") {
                            $groupId = $matches[1]
                            Write-Host "Group ID extracted: $groupId"

                            # Get group display name
                            $group = Get-MgGroup -GroupId $groupId
                            $groupName = $group.DisplayName

                            $reviewerGroupsList += [PSCustomObject]@{
                                AccessPackageID = $extractedId
                                ReviewerGroupName = $groupName
                                ReviewerGroupId   = $groupId
                            }
                        } else {
                            Write-Host "Reviewer query not resolvable: $reviewerQuery"
                            $reviewerGroupsList += [PSCustomObject]@{
                                AccessPackageID     = $extractedId
                                ReviewerGroupName   = "Reviewer query not resolvable"
                                ReviewerGroupId     = ""
                            }
                        }
                    }
                } else {
                    Write-Host "No reviewers assigned to this review."
                    $reviewerGroupsList += [PSCustomObject]@{
                        AccessPackageID     = $extractedId
                        ReviewerGroupName   = "No reviewers assigned"
                        ReviewerGroupId     = ""
                    }
                }
            }
        }
    }

    return $reviewerGroupsList
}


# --- Run Everything ---
Write-LogInfo("Script execution started")

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

$groupsDictionary = Get-GroupsDictionary
$getAllAccessPackagesWithResources = Get-ResourcesFromAccessPackages -GroupDictionary $groupsDictionary

# Get unique group IDs and access package IDs
$groupIDs = $getAllAccessPackagesWithResources.GroupID | Select-Object -Unique
$accessPackageIDs = $getAllAccessPackagesWithResources.AccessPackageID | Select-Object -Unique

# Function to Get Entra Role Assignments for Access Package-Linked Groups
$entraRoles = Get-EntraRolesForGroups -GroupIDs $groupIDs

# Get Group owners from Access package Group ID's above
$groupOwners = Get-GroupOwnersWithNames -GroupIDs $groupIDs

# Get Access reviewers
$accessReviewers = Get-AccessReviewGroups -AccessPackageIDs $accessPackageIDs

# --- Merge Everything ---

# Loop through each access package entry and enrich it with related role, owner, and reviewer data
$mergedExport = foreach ($entry in $getAllAccessPackagesWithResources) {

    # Find any Entra role assignments or eligibilities linked to the group in this access package
    $matchingRoles = $entraRoles | Where-Object { $_.GroupID -eq $entry.GroupID }

    # Find the owners of the group associated with this access package
    $matchingOwners = $groupOwners | Where-Object { $_.GroupID -eq $entry.GroupID }

    # Find reviewers assigned to the access package (via access reviews
    $matchingReviewers = $accessReviewers | Where-Object { $_.AccessPackageID -eq $entry.AccessPackageID }

    # Combine owner names into a single string
    $ownerNames = ($matchingOwners | Select-Object -ExpandProperty OwnerName) -join ', '

    # Combine reviewer names into a single string
    $reviewerNames = ($matchingReviewers | Select-Object -ExpandProperty ReviewerGroupName) -join ', '
    #OLD $reviewerNames = ($matchingReviewers | Select-Object -ExpandProperty ReviewerName) -join ', '


    # If no Entra roles are assigned to the group, return a single entry with empty role fields
    if ($matchingRoles.Count -eq 0) {
        [PSCustomObject][Ordered]@{
            Catalog           = $entry.Catalog
            #CatalogID         = $entry.CatalogID 
            AccessPackage     = $entry.AccessPackage
            #AccessPackageID   = $entry.AccessPackageID
            GroupDisplayname  = $entry.GroupDisplayname
            #GroupID           = $entry.GroupID
            RoleName          = "No role found"
            #RoleDescription   = "No role found"
            #Scope             = "No role found"
            AssignmentType    = "no role found"
            RoleStatus        = "no role found"
            GroupOwners       = $ownerNames
            AccessReviewers   = $reviewerNames
        }
         # If roles are found, return one entry per role assignment
    } else {
        foreach ($role in $matchingRoles) {
            [PSCustomObject][Ordered]@{
                Catalog           = $entry.Catalog
                AccessPackage     = $entry.AccessPackage
                GroupDisplayname  = $entry.GroupDisplayname
                RoleName          = $role.RoleName
                AssignmentType    = $role.AssignmentType
                RoleStatus        = $role.RoleStatus
                GroupOwners       = $ownerNames
                AccessReviewers   = $reviewerNames
            }
        }
    }
}
###$ JUST FOR TESTING OUTPUT###mergedExport | ForEach-Object { $_ } | Export-Csv -Path "$ExportToExcelPath\AccessPackageResourcesWithRoles.csv" -NoTypeInformation



### JUST FOR TESTING Testing##$ExportToExcelPath = 
###$ JUST FOR TESTING OUTPUT###mergedExport | ForEach-Object { $_ } | Export-Csv -Path "$ExportToExcelPath\AccessPackageResourcesWithRoles.csv" -NoTypeInformation


#Convert the $mergedExport to JSON to send it to Log analytics
$JSONMergedExport = $mergedExport | ConvertTo-Json
PostLogAnalyticsData -logBody $JSONMergedExport -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName
