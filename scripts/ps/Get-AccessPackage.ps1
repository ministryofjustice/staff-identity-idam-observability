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

    Write-LogInfo("Eligible roles returned: $($eligibleRoles.Count)") #Counting all Eligible roles
    Write-LogInfo("Active roles returned: $($activeRoles.Count)") #Count all Active roles
    Write-LogInfo("Role Definitions returned: $($roleDefinitions.Count)") #Count all Active roles

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
        Get-MgEntitlementManagementAccessPackage -AccessPackageId $pkg.Id -ExpandProperty "resourceRoleScopes(`$expand=scope,role)", "catalog"
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
                $catalogName = $accessPackage.Catalog.DisplayName
                $group = Get-MgGroup -GroupId $scope.OriginId -ErrorAction Stop #Forces terminating error to go to catch
                $mems = Get-MgGroupMember -GroupId $group.id
                $exportList += [PSCustomObject][Ordered]@{
                    AccessPackage    = $accessPackage.DisplayName
                    AccessPackageID  = $accessPackage.Id
                    Displayname      = $group.DisplayName
                    Description      = $group.Description
                    ScopeType        = "EntraGroup"  
                    GroupID          = $group.id
                    CatalogName      = $catalogName
                    NumberOfMembers  = $mems.Count    
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
                        CatalogName      = $catalogName
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
                            CatalogName      = $catalogName 
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
        Write-LogInfo("Processing review: $($review.DisplayName)")
        Write-LogInfo("Scope query: $query")

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
                            try {
                                
                                $group = Get-MgGroup -GroupId $groupId
                                $groupName = $group.DisplayName

                                #lets get the members of this reviewgroup as well
                                $memberids = Get-MgGroupMember -GroupId $group.id
                                
                                #if members of group found
                                if ($memberids) {
                                    Write-Host "Getting users from group $($groupName)"
                                    $listofusers = @()
                                    foreach ($memberid in $memberids) {
                                        $user = Get-MgUser -UserId $memberid.Id
                                        $listofusers += [PSCustomObject]@{
                                        UserPrincipalName = $user.UserPrincipalName
                                        DisplayName       = $user.DisplayName
                                        Id                = $user.Id
                                        }
                                    }
                                } #if the group has members, do this
                                else {
                                    write-host "No members in reviewer group"
                                    $listofusers = "No members in group"
                                }

                                $reviewerGroupsList += [PSCustomObject]@{
                                    AccessPackageID = $extractedId
                                    ReviewerGroupName = $groupName
                                    ReviewerGroupId   = $groupId
                                    ListOfUsers = ($listofusers | ConvertTo-Json -Compress)
                                }
                            
                            } catch {
                                Write-Host "Reviewer query not resolvable: $reviewerQuery"
                                $reviewerGroupsList += [PSCustomObject]@{
                                    AccessPackageID     = $extractedId
                                    ReviewerGroupName   = "Reviewer query not resolvable"
                                    ReviewerGroupId     = "No reviewer"
                                    ListOfUsers = $listofusers
                                }
                            }
                        } else {
                            Write-Host "Reviewer query not resolvable: $reviewerQuery"
                            $reviewerGroupsList += [PSCustomObject]@{
                                AccessPackageID     = $extractedId
                                ReviewerGroupName   = "Reviewer query not resolvable"
                                ReviewerGroupId     = "No reviewer"
                                ListOfUsers = $listofusers
                            }
                        }
                    }
                } else {
                    Write-Host "No reviewers assigned to this review."
                    $reviewerGroupsList += [PSCustomObject]@{
                        AccessPackageID     = $extractedId
                        ReviewerGroupName   = "No reviewers assigned"
                        ReviewerGroupId     = "No reviewer assigned"
                    }
                }
            }
        }
    }

    return $reviewerGroupsList
}

function Get-AccessReviewAssignment {

    try {
        Write-LogInfo("Trying to retrieve access packages")
        $allPackages = Get-MgEntitlementManagementAccessPackage
    }
    catch {
        Write-LogInfo("Unable to retrieve packages")
    }

    if ($allPackages) {
        #Empty array of all the assignments
        $ListOfAssignments = @()
        foreach ($package in $allPackages) {
            try {
                Write-Host "Trying to get assignments on access package"
                $assignments = Get-MgEntitlementManagementAssignment -Filter "accessPackage/id eq '$($package.id)'" -ExpandProperty target
            }
            catch {
                Write-Host "Unable to get assignment information."
            }
            if ($assignments) {
                Write-Host "Iterate through the assignments and add them to the array"
                foreach ($assignment in $assignments) {
                    $ListOfAssignments += [PSCustomObject]@{
                        AccessPackage = $Package.DisplayName
                        AssignmentEmail = $assignment.target.email
                    }
                }
            }
            else {
                Write-Host "Access Package has no assignments"
                $ListOfAssignments += [PSCustomObject]@{
                    AccessPackage = $Package.DisplayName
                    AssignmentEmail = "Access package has no assignments"
                }
            }
        }
    }
    else {
        Write-Host "Unable to get Assigment details"
    }
    return $ListOfAssignments
}

#Run Azure authentication

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

#List of who has access to which access package
$accesspackageassignments = Get-AccessReviewAssignment
    
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

    $assignments = $accesspackageassignments  | Where-Object { $_.AccessPackage -eq $package.accessPackage }

    $assignments = if ($null -ne $assignments.AssignmentEmail) {
    if ($assignments.AssignmentEmail -is [array]) {
        $assignments.AssignmentEmail -join ", "
    } else {
        $assignments.AssignmentEmail
    }
}

    # If no roles found, still output one row
    if ($roles.Count -eq 0) {
        [PSCustomObject]@{
            AccessPackage              = $package.AccessPackage
            AccessPackageID            = $accessPackageID
            DisplayName                = $package.DisplayName
            Description                = $package.Description
            ScopeType                  = $package.ScopeType
            GroupID                    = $groupID
            CatalogName                = $package.CatalogName
            NumberOfGroupMembers       = [int]$package.NumberOfMembers
            RoleName                   = "This resource does not have a role"
            RoleDescription            = "No description"
            AssignmentType             = "No assignment type for this resource"
            RoleStatus                 = "This resource does not have a role"
            AccessReviewerGroupUsers   = $reviewer.listofusers
            ReviewerGroupName          = $reviewer.ReviewerGroupName
            ReviewerGroupId            = $reviewer.ReviewerGroupId
            Assignments                = $assignments
        }
    }
    else {
        foreach ($role in $roles) {
            [PSCustomObject]@{
                AccessPackage              = $package.AccessPackage
                AccessPackageID            = $accessPackageID
                DisplayName                = $package.DisplayName
                Description                = $package.Description
                ScopeType                  = $package.ScopeType
                GroupID                    = $groupID
                CatalogName                = $package.CatalogName 
                NumberOfGroupMembers       = [int]$package.NumberOfMembers
                RoleName                   = $role.RoleName
                RoleDescription            = $role.RoleDescription
                AssignmentType             = $role.AssignmentType
                RoleStatus                 = $role.RoleStatus
                ListOfUsers                = $reviewer.listofusers
                ReviewerGroupName          = $reviewer.ReviewerGroupName
                ReviewerGroupId            = $reviewer.ReviewerGroupId
                AccessReviewerGroupUsers   = $reviewer.listofusers
                Assignments                = $assignments
            }
        }
    }
}

#Use function to post to Log Analytics
Write-LogInfo("Post data to Log Analytics")
GroupPostResults($combinedObjects)

Write-LogInfo("Script execution finished")
