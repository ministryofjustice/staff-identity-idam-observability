resource "azapi_resource" "workspaces_table" {
  type      = "Microsoft.OperationalInsights/workspaces/tables@2021-12-01-preview"
  name      = "${var.department}_${var.team}_${var.project}_logs_CL"
  parent_id = azurerm_log_analytics_workspace.log_analytics_workspace.id

  body = jsonencode({
    properties = {
      plan = "Analytics",
      schema = {
        name = "${var.department}_${var.team}_${var.project}_logs_CL",
        columns = [
          {
            name = "displayname",
            type = "string"
          },
          {
            name = "objectid",
            type = "string"
          },
          {
            name = "applicationid",
            type = "string"
          },
          {
            name = "keyid",
            type = "string"
          },
          {
            name = "eventtype",
            type = "string"
          },
          {
            name = "startdate",
            type = "dateTime"
          },
          {
            name = "enddate",
            type = "dateTime"
          },
          {
            name = "status",
            type = "string"
          },
          {
            name = "TimeGenerated",
            type = "dateTime"
          },
          {
            name = "daystoexpiration",
            type = "int"
          },
          {
            name = "owners",
            type = "string"
          }
        ]
      }
    }
  })
  response_export_values = ["*"]

  depends_on = [
    azurerm_log_analytics_workspace.log_analytics_workspace
  ]
}

resource "azapi_resource" "workspaces_table_access_package_info" {
  type      = "Microsoft.OperationalInsights/workspaces/tables@2021-12-01-preview"
  name      = "${var.department}_${var.team}_${var.project}_AccessPackage_CL"
  parent_id = azurerm_log_analytics_workspace.log_analytics_workspace.id

  body = jsonencode({
    properties = {
      plan = "Analytics",
      schema = {
        name = "${var.department}_${var.team}_${var.project}_AccessPackage_CL",
        columns = [
          {
            name = "AccessPackage",
            type = "string"
          },
          {
            name = "AccessPackageID",
            type = "string"
          },
          {
            name = "DisplayName",
            type = "string"
          },
          {
            name = "Description",
            type = "string"
          },
          {
            name = "ScopeType",
            type = "string"
          },
          {
            name = "GroupID",
            type = "string"
          },
          {
            name = "CatalogName",
            type = "string"
          },
          {
            name = "NumberOfGroupMembers",
            type = "int"
          },
          {
            name = "RoleName",
            type = "string"
          },
          {
            name = "RoleDescription",
            type = "string"
          },
          {
            name = "AssignmentType",
            type = "string"
          },
          {
            name = "RoleStatus",
            type = "string"
          },
          {
            name = "ListOfUsers",
            type = "string"
          },
          {
            name = "ReviewerGroupName",
            type = "string"
          },
          {
            name = "ReviewerGroupId",
            type = "string"
          },
          {
            name = "AccessReviewerGroupUsers",
            type = "string"
          },
          {
            name = "Assignments",
            type = "string"
          },
          {
            name = "TimeGenerated",
            type = "dateTime"
          }
        ]
      }
    }
  })
  response_export_values = ["*"]

  depends_on = [
    azurerm_log_analytics_workspace.log_analytics_workspace
  ]
}

resource "azapi_resource" "workspaces_table_creds_cleanup_script" {
  type      = "Microsoft.OperationalInsights/workspaces/tables@2021-12-01-preview"
  name      = "${var.department}_${var.team}_${var.project}_creds_cleanup_logs_CL"
  parent_id = azurerm_log_analytics_workspace.log_analytics_workspace.id

  body = jsonencode({
    properties = {
      plan = "Analytics",
      schema = {
        name = "${var.department}_${var.team}_${var.project}_creds_cleanup_logs_CL",
        columns = [
          {
            name = "displayname",
            type = "string"
          },
          {
            name = "cleanup",
            type = "string"
          },
          {
            name = "objectid",
            type = "string"
          },
          {
            name = "applicationid",
            type = "string"
          },
          {
            name = "keyid",
            type = "string"
          },
          {
            name = "credtype",
            type = "string"
          },
          {
            name = "startdate",
            type = "dateTime"
          },
          {
            name = "enddate",
            type = "dateTime"
          },
          {
            name = "status",
            type = "string"
          },
          {
            name = "TimeGenerated",
            type = "dateTime"
          },
          {
            name = "daystoexpiration",
            type = "int"
          },
          {
            name = "owners",
            type = "string"
          }
        ]
      }
    }
  })
  response_export_values = ["*"]

  depends_on = [
    azurerm_log_analytics_workspace.log_analytics_workspace
  ]
}

resource "azapi_resource" "workspaces_table_guest_users" {
  type      = "Microsoft.OperationalInsights/workspaces/tables@2021-12-01-preview"
  name      = "${var.department}_${var.team}_${var.project}_GuestUsers_CL"
  parent_id = azurerm_log_analytics_workspace.log_analytics_workspace.id

  body = jsonencode({
    properties = {
      plan = "Analytics",
      schema = {
        name = "${var.department}_${var.team}_${var.project}_GuestUsers_CL",
        columns = [
          {
            name = "displayname",
            type = "string"
          },
          {
            name = "objectid",
            type = "string"
          },
          {
            name = "mail",
            type = "string"
          },
          {
            name = "userPrincipleName",
            type = "string"
          },
          {
            name = "accountEnabled",
            type = "bool"
          },
          {
            name = "createdDateTime",
            type = "dateTime"
          },
          {
            name = "externalUserState",
            type = "string"
          },
          {
            name = "lastLoginDate",
            type = "dateTime"
          },
          {
            name = "hasLoggedIn",
            type = "bool"
          },
          {
            name = "daysSinceInvitedAndNotRegistered",
            type = "int"
          },
          {
            name = "daysInactive",
            type = "int"
          },
          {
            name = "isInactiveAfterPolicyDays",
            type = "bool"
          },
          {
            name = "isNotActivatedAfterPolicyDays",
            type = "bool"
          },
          {
            name = "isInactiveAfterExternalPolicyDays",
            type = "bool"
          },
          {
            name = "isNotActivatedAfterExternalPolicyDays",
            type = "bool"
          },
          {
            name = "TimeGenerated",
            type = "dateTime"
          }
        ]
      }
    }
  })
  response_export_values = ["*"]

  depends_on = [
    azurerm_log_analytics_workspace.log_analytics_workspace
  ]
}

resource "azapi_resource" "workspaces_table_guest_del_script" {
  type      = "Microsoft.OperationalInsights/workspaces/tables@2021-12-01-preview"
  name      = "${var.department}_${var.team}_${var.project}_guest_del_logs_CL"
  parent_id = azurerm_log_analytics_workspace.log_analytics_workspace.id

  body = jsonencode({
    properties = {
      plan = "Analytics",
      schema = {
        name = "${var.department}_${var.team}_${var.project}_guest_del_logs_CL",
        columns = [
          {
            name = "id",
            type = "string"
          },
          {
            name = "displayname",
            type = "string"
          },
          {
            name = "userprincipalname",
            type = "string"
          },
          {
            name = "createddatetime",
            type = "dateTime"
          },
          {
            name = "dayssincecreated",
            type = "int"
          },
          {
            name = "lastlogindate",
            type = "dateTime"
          },
          {
            name = "daysinactive",
            type = "int"
          },
          {
            name = "companyname",
            type = "string"
          },
          {
            name = "jobtitle",
            type = "string"
          },
          {
            name = "department",
            type = "string"
          },
          {
            name = "cleanup",
            type = "string"
          },
          {
            name = "deletetype",
            type = "string"
          },
          {
            name = "TimeGenerated",
            type = "dateTime"
          }
        ]
      }
    }
  })
  response_export_values = ["*"]

  depends_on = [
    azurerm_log_analytics_workspace.log_analytics_workspace
  ]
}

resource "azapi_resource" "workspaces_table_mfa_metrics" {
  type      = "Microsoft.OperationalInsights/workspaces/tables@2021-12-01-preview"
  name      = "${var.department}_${var.team}_${var.project}_mfa_metrics_logs_CL"
  parent_id = azurerm_log_analytics_workspace.log_analytics_workspace.id

  body = jsonencode({
    properties = {
      plan = "Analytics",
      schema = {
        name = "${var.department}_${var.team}_${var.project}_mfa_metrics_logs_CL",
        columns = [
          {
            name = "TimeGenerated",
            type = "dateTime"
          },
          {
            name = "TotalEnabledNonGuestUsers",
            type = "int"
          },
          {
            name = "MFAenrolled",
            type = "int"
          },
          {
            name = "MFAenrolledPercent",
            type = "real"
          },
          {
            name = "PhoneCount",
            type = "int"
          },
          {
            name = "PhoneMFAPercent",
            type = "real"
          },
          {
            name = "AuthenticatorCount",
            type = "int"
          },
          {
            name = "AuthenticatorMFAPercent",
            type = "real"
          },
          {
            name = "HardwareCount",
            type = "int"
          },
          {
            name = "HardwareMFAPercent",
            type = "real"
          },
          {
            name = "WindowsHelloCount",
            type = "int"
          },
          {
            name = "WindowsHelloMFAPercent",
            type = "real"
          },
          {
            name = "ZeroMethodsRegistered",
            type = "int"
          },
          {
            name = "OneMethodRegistered",
            type = "int"
          },
          {
            name = "TwoMethodsRegistered",
            type = "int"
          },
          {
            name = "ThreeMethodsRegistered",
            type = "int"
          },
          {
            name = "FourPlusMethodsRegistered",
            type = "int"
          }
        ]
      }
    }
  })
  response_export_values = ["*"]

  depends_on = [
    azurerm_log_analytics_workspace.log_analytics_workspace
  ]
}

resource "azurerm_log_analytics_workspace_table" "mfa_metrics" {
  workspace_id            = azurerm_log_analytics_workspace.log_analytics_workspace.id
  name                    = azapi_resource.workspaces_table_mfa_metrics.name
  retention_in_days       = 365
  total_retention_in_days = 365

  depends_on = [azapi_resource.workspaces_table_mfa_metrics]
}

resource "azapi_resource" "workspaces_table_user_metrics" {
  type      = "Microsoft.OperationalInsights/workspaces/tables@2021-12-01-preview"
  name      = "${var.department}_${var.team}_${var.project}_user_metrics_logs_CL"
  parent_id = azurerm_log_analytics_workspace.log_analytics_workspace.id

  body = jsonencode({
    properties = {
      plan = "Analytics",
      schema = {
        name = "${var.department}_${var.team}_${var.project}_user_metrics_logs_CL",
        columns = [
          {
            name = "TimeGenerated",
            type = "dateTime"
          },
          {
            name = "TotalAccounts",
            type = "int"
          },
          {
            name = "TotalServiceAccounts",
            type = "int"
          },
          {
            name = "TotalGuests",
            type = "int"
          },
          {
            name = "TotalEnabledAccounts",
            type = "int"
          },
          {
            name = "TotalDisabledAccounts",
            type = "int"
          },
          {
            name = "NotUsedForAYear",
            type = "int"
          }
        ]
      }
    }
  })
  response_export_values = ["*"]

  depends_on = [
    azurerm_log_analytics_workspace.log_analytics_workspace
  ]
}

resource "azurerm_log_analytics_workspace_table" "user_metrics" {
  workspace_id            = azurerm_log_analytics_workspace.log_analytics_workspace.id
  name                    = azapi_resource.workspaces_table_user_metrics.name
  retention_in_days       = 365
  total_retention_in_days = 365

  depends_on = [azapi_resource.workspaces_table_user_metrics]
}
