$DebugPreference = 'Continue'
$VerbosePreference = "Continue"
BeforeAll {
    # at the top of the file
    $params = @{
        MiClientId     = "MiClientId_test"
        DcrImmutableId = "DcrImmutableId_test"
        DceUri         = "dceuri_test"
        LogTableName   = "lt_test"
    }
    $md_Group_MoJoExternalSyncLegalAidAgencyStaff = [PSCustomObject]@{
        Id = "00000000-0000-0000-0000-000000000001"
    }
    $md_Group_ExternalEmailTempTestTenantAccess = [PSCustomObject]@{
        Id = "00000000-0000-0000-0000-000000000002"
    }
    $md_Group_Users_MoJoExternalSyncLegalAidAgencyStaff = @(
        [PSCustomObject]@{
            DisplayName = "MoJoExternalSyncLegalAidAgencyStaff Test 1"
            Id          = "00000000-0000-0000-0000-000000000010"
            Mail        = "MoJoExternalSyncLegalAidAgencyStaff.test1@justice.gov.uk"
            UserPrincipalName        = "MoJoExternalSyncLegalAidAgencyStaff.test1@justice.gov.uk"
            SignInActivity        = [PSCustomObject]@{
                LastSignInDateTime = (Get-Date)
            }
            CompanyName        = "LAAD"
            JobTitle        = "Internal SilAS Test Account"
            Department        = "Legal Aid Agency"
            CreatedDateTime        = (Get-Date)
        },
        [PSCustomObject]@{
            DisplayName = "MoJoExternalSyncLegalAidAgencyStaff Test 2"
            Id          = "00000000-0000-0000-0000-000000000020"
            Mail        = "MoJoExternalSyncLegalAidAgencyStaff.test2@justice.gov.uk"
            UserPrincipalName        = "MoJoExternalSyncLegalAidAgencyStaff.test2@justice.gov.uk"
            SignInActivity        = [PSCustomObject]@{
                LastSignInDateTime = (Get-Date)
            }
            CompanyName        = "LAAD"
            JobTitle        = "Internal SilAS Test Account"
            Department        = "Legal Aid Agency"
            CreatedDateTime        = (Get-Date)
        }
    )
    $md_Group_Users_ExternalEmailTempTestTenantAccess = @(
        [PSCustomObject]@{
            DisplayName = "ExternalEmailTempTestTenantAccess Test 1"
            Id          = "00000000-0000-0000-0000-000000000030"
            Mail        = "ExternalEmailTempTestTenantAccess.test1@justice.gov.uk"
            UserPrincipalName        = "ExternalEmailTempTestTenantAccess.test1@justice.gov.uk"
            SignInActivity        = [PSCustomObject]@{
                LastSignInDateTime = (Get-Date).AddDays(-90)
            }
            CompanyName        = "LAAD"
            JobTitle        = "External Email SilAS Test Account"
            Department        = "Legal Aid Agency"
            CreatedDateTime        = (Get-Date).AddDays(-90)
        },
        [PSCustomObject]@{
            DisplayName = "ExternalEmailTempTestTenantAccess Test 2"
            Id          = "00000000-0000-0000-0000-000000000040"
            Mail        = "ExternalEmailTempTestTenantAccess.test2@justice.gov.uk"
            UserPrincipalName        = "ExternalEmailTempTestTenantAccess.test2@justice.gov.uk"
            SignInActivity        = [PSCustomObject]@{
                LastSignInDateTime = (Get-Date)
            }
            CompanyName        = "LAAD"
            JobTitle        = "External Email SilAS Test Account"
            Department        = "Legal Aid Agency"
            CreatedDateTime        = (Get-Date)
        }
    )
    . $PSScriptRoot/process-guest-user-delete-devl.ps1
}

Context "When connecting to graph" {
    BeforeEach{
        Mock -CommandName GroupPostResults {}
        Mock ConnectToGraph {}

        #Mock GetGroupMembers {} -Verifiable -ParameterFilter {$version -eq 1.2}

        Mock -CommandName GetGroupMembers -parameterFilter { $GroupName -eq 'MoJo-External-Sync-Legal-Aid-Agency-Staff'} -MockWith { $md_Group_Users_MoJoExternalSyncLegalAidAgencyStaff }
        
        Mock -CommandName GetGroupMembers -parameterFilter { $GroupName -eq 'External-Email-Temp-Test-Tenant-Access'} -MockWith { $md_Group_Users_ExternalEmailTempTestTenantAccess }
        
        Mock -CommandName Get-MgUser -MockWith {
            param($UserId)
            $user = $md_Group_Users_ExternalEmailTempTestTenantAccess | Where-Object { $_.Id -eq $UserId }
            if (-not $user) {
                $user = $md_Group_Users_MoJoExternalSyncLegalAidAgencyStaff | Where-Object { $_.Id -eq $UserId }
            }
            if (-not $user) {
                throw "Mock user not found for '$UserId'"
            }
            return $user
        }

        Run -MiClientId $params.MiClientId -DcrImmutableId $params.DcrImmutableId -DceUri $params.DceUri -LogTableName $params.LogTableName
    }
    It "Should call Connect Graph Functions" {
        Assert-MockCalled ConnectToGraph -Times 1
    }

    It "Should call Send data to endpoint" {
        Assert-MockCalled GroupPostResults -Times 1
    }

    It "Should call Get-MgUser" {
        Assert-MockCalled Get-MgUser -Times 2
    }

    It "Should return 2 users ready for deletion" {        
        Assert-MockCalled GroupPostResults -Times 1 -ParameterFilter {
            Write-Log($postData)
            $dataObject = $postData | ConvertFrom-Json
            ($dataObject.Count -eq 2) -and
            ($dataObject | Where-Object { "00000000-0000-0000-0000-000000000030" -eq $_.Id}) -and
            ($dataObject | Where-Object { "00000000-0000-0000-0000-000000000010" -eq $_.Id}) -and
            (($dataObject | Where-Object { "externalsync" -eq $_.deletetype}).Count -eq 1) -and
            (($dataObject | Where-Object { "temporaryemail" -eq $_.deletetype}).Count -eq 1)
        }
    }
}
