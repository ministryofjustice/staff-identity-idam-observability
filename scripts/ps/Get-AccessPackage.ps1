<#
    .SYNOPSIS
    A script that gets owners, roles and information about access packages
     
    .DESCRIPTION
    Leverage Microsoft Graph API and PowerShell to fetch a list Catalogs, Access packages and groups #>

param(
    [string]$MIclientId,
    [string]$DcrImmutableId,
    [string]$DceUri,
    [string]$LogTableName
)


#Function to write log info
function Write-LogInfo($logentry) {
    Write-Output "$(get-date -Format "yyyy-MM-dd HH:mm:ss K") - $($logentry)"
}

#Function to post to log analytics in stages
function GroupPostResults($postData) {
    for ($i = 0; $i -lt $postData.Count; $i += 500) {
        $batchNumber = ([Math]::Min($i+499, $postData.Count-1))
        $postDataBatch = $postData[$i..$batchNumber]

        $json = $postDataBatch | ConvertTo-Json -Depth 10

        PostLogAnalyticsData -logBody $json -dcrImmutableId $DcrImmutableId -dceUri $DceUri -table $LogTableName
        
        Write-LogInfo("Sent batch from $($i+1) to $($batchNumber+1))")   
    }
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

function Get-AccessPackageResources {
    # Initialize an empty array to store the final data
    $exportList = @()


    #Get info on all access packages
    $allPackages = Get-MgEntitlementManagementAccessPackage


    #Having to expand each individually to get the resource role scope due to a limitation in graph
    $expandedPackages = foreach ($pkg in $allPackages) {
        Get-MgEntitlementManagementAccessPackage -AccessPackageId $pkg.Id -ExpandProperty "resourceRoleScopes(`$expand=scope,role)"
    } 

    # Track how many access packages are in this catalog
    $totalAccessPackagesInCatalog = $accessPackages.count

    #Iteration counter in for loop
    $counter = 1


    #Loop through each access package and get the group
    foreach ($accessPackage in $expandedPackages) {
        Write-Host "`t[$counter/$($totalAccessPackagesInCatalog)][Access Package: $($accessPackage.DisplayName)]"
        $counter++


        #Time to iterate throught he scopes (Groups, apps) in the resourcerolescopes
        foreach ($scope in $accessPackage.ResourceRoleScopes.Scope) {
            try {
                $group = Get-MgGroup -GroupId $scope.OriginId -ErrorAction Stop #Forces terminating error to go to catch
                $exportList += [PSCustomObject][Ordered]@{
                    AccessPackage    = $accessPackage.DisplayName
                    AccessPackageID  = $accessPackage.Id
                    Displayname      = $group.DisplayName
                    Description      = $group.Description
                    ScopeType        = "EntraGroup"  
                    GroupID          = $group.id    
                }

            }
            catch {
                #If get group command errors, check for enterprise app
                Write-Host "No Group found, trying Enterprise App"

                try {
                    #Get the service principal
                    $app = Get-MgServicePrincipal -ServicePrincipalId $scope.OriginId -ErrorAction Stop #Forces terminating error to go to catch
                    $exportList += [PSCustomObject][Ordered]@{
                        AccessPackage    = $accessPackage.DisplayName
                        AccessPackageID  = $accessPackage.Id
                        Displayname      = $app.DisplayName
                        Description      = "Enterprise application"
                        ScopeType        = "ServicePrincipal"
                    }

                }
                catch {
                    Write-Host "No Enterprise App found, checking App reg."
                    #If enterprise app fails, check for app reg

                    try {
                        $app = Get-MgApplicaiton -Applicationid $scope.OriginId #Forces terminating error to go to catch
                        $exportList += [PSCustomObject][Ordered]@{
                            AccessPackage    = $accessPackage.DisplayName
                            AccessPackageID  = $accessPackage.Id
                            Displayname      = $app.DisplayName
                            Description      = "App Registration"
                            ScopeType        = "AppRegistration"
                        }
                    }
                    catch {
                       write-host "No Groups, or apps found"
                    }


                }
            }
        }
    }
    return $exportList
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

#Run stuff

Write-LogInfo("Script execution started")
Write-LogInfo("Authenticate with the credentials object.")
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

#Get the groups / apps on the access packages
$accesspackageResourceinfo = Get-AccessPackageResources

#Unique Access package Group ID's into variable
$groupids = $accesspackageResourceinfo.GroupID | Select-Object -Unique

#Call the function to get roles from the Groups on the access packages using each access package groupid
$entraRoles = Get-EntraRolesForGroups -GroupIDs $groupIDs

#Get info on the access reviewers groups
$accessPackageIDs = $accesspackageResourceinfo | Select-Object -ExpandProperty AccessPackageID -Unique
$accessReviewers = Get-AccessReviewGroups -AccessPackageIDs $accessPackageIDs

#Combining $accesspackageResourceinfo, $entraRoles and $accessReviewers into useful data
$combinedObjects = foreach ($package in $accesspackageResourceinfo) {
    $accessPackageID = $package.AccessPackageID
    $groupID = $package.GroupID

    $roles = $entraRoles | Where-Object { $_.GroupID -eq $groupID }
    $reviewer = $accessReviewers | Where-Object { $_.AccessPackageID -eq $accessPackageID }

    # If no roles found, still output one row
    if ($roles.Count -eq 0) {
        [PSCustomObject]@{
            AccessPackage       = $package.AccessPackage
            AccessPackageID     = $accessPackageID
            DisplayName         = $package.DisplayName
            Description         = $package.Description
            ScopeType           = $package.ScopeType
            GroupID             = $groupID

            RoleName            = $null
            RoleDescription     = $null
            AssignmentType      = $null
            RoleStatus          = $null

            ReviewerGroupName   = $reviewer.ReviewerGroupName
            ReviewerGroupId     = $reviewer.ReviewerGroupId
        }
    }
    else {
        foreach ($role in $roles) {
            [PSCustomObject]@{
                AccessPackage       = $package.AccessPackage
                AccessPackageID     = $accessPackageID
                DisplayName         = $package.DisplayName
                Description         = $package.Description
                ScopeType           = $package.ScopeType
                GroupID             = $groupID

                RoleName            = $role.RoleName
                RoleDescription     = $role.RoleDescription
                AssignmentType      = $role.AssignmentType
                RoleStatus          = $role.RoleStatus

                ReviewerGroupName   = $reviewer.ReviewerGroupName
                ReviewerGroupId     = $reviewer.ReviewerGroupId
            }
        }
    }
}



#Use function to post to Log Analytics
Write-LogInfo("Post data to Log Analytics")
GroupPostResults($combinedObjects)

Write-LogInfo("Script execution finished")
