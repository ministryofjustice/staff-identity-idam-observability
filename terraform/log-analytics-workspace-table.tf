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
            name = "ReviewerGroupName",
            type = "string"
          },
          {
            name = "ReviewerGroupId",
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

resource "azapi_resource" "workspaces_table_guest_user_delete_script" {
  type      = "Microsoft.OperationalInsights/workspaces/tables@2021-12-01-preview"
  name      = "${var.department}_${var.team}_${var.project}_guest_user_delete_logs_CL"
  parent_id = azurerm_log_analytics_workspace.log_analytics_workspace.id

  body = jsonencode({
    properties = {
      plan = "Analytics",
      schema = {
        name = "${var.department}_${var.team}_${var.project}_guest_user_delete_logs_CL",
        columns = [
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
            type = "dateTime"
          },
          {
            name = "jobtitle",
            type = "dateTime"
          },
          {
            name = "department",
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
