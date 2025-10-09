resource "azurerm_monitor_data_collection_rule" "data_collection_rule" {
  name                        = "dcr-${var.department}-${var.team}-${var.project}"
  location                    = var.location
  resource_group_name         = local.rg_name
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.data_collection_endpoint.id

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.log_analytics_workspace.id
      name                  = azurerm_log_analytics_workspace.log_analytics_workspace.name
    }
  }

  data_flow {
    streams       = ["Custom-${azapi_resource.workspaces_table.name}"]
    destinations  = [azurerm_log_analytics_workspace.log_analytics_workspace.name]
    transform_kql = "source"
    output_stream = "Custom-${azapi_resource.workspaces_table.name}"
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.managed_identity.id
    ]
  }

  stream_declaration {
    stream_name = "Custom-${azapi_resource.workspaces_table.name}"
    column {
      name = "displayname"
      type = "string"
    }
    column {
      name = "objectid"
      type = "string"
    }
    column {
      name = "applicationid"
      type = "string"
    }
    column {
      name = "keyid"
      type = "string"
    }
    column {
      name = "eventtype"
      type = "string"
    }
    column {
      name = "startdate"
      type = "datetime"
    }
    column {
      name = "enddate"
      type = "datetime"
    }
    column {
      name = "status"
      type = "string"
    }
    column {
      name = "TimeGenerated"
      type = "datetime"
    }
    column {
      name = "daystoexpiration"
      type = "int"
    }
    column {
      name = "owners"
      type = "string"
    }
  }

  description = "Data collection rule"
  depends_on = [
    azapi_resource.workspaces_table,
    azurerm_monitor_data_collection_endpoint.data_collection_endpoint
  ]

  tags = local.tags
}

resource "azurerm_monitor_data_collection_rule" "data_collection_rule_cleanup" {
  name                        = "dcr-${var.department}-${var.team}-${var.project}-cleanup"
  location                    = var.location
  resource_group_name         = local.rg_name
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.data_collection_endpoint.id

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.log_analytics_workspace.id
      name                  = azurerm_log_analytics_workspace.log_analytics_workspace.name
    }
  }

  data_flow {
    streams       = ["Custom-${azapi_resource.workspaces_table_creds_cleanup_script.name}"]
    destinations  = [azurerm_log_analytics_workspace.log_analytics_workspace.name]
    transform_kql = "source"
    output_stream = "Custom-${azapi_resource.workspaces_table_creds_cleanup_script.name}"
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.managed_identity.id
    ]
  }

  stream_declaration {
    stream_name = "Custom-${azapi_resource.workspaces_table_creds_cleanup_script.name}"
    column {
      name = "displayname"
      type = "string"
    }
    column {
      name = "cleanup"
      type = "string"
    }
    column {
      name = "applicationid"
      type = "string"
    }
    column {
      name = "credtype"
      type = "string"
    }
    column {
      name = "startdate"
      type = "datetime"
    }
    column {
      name = "enddate"
      type = "datetime"
    }
    column {
      name = "daystoexpiration"
      type = "int"
    }
    column {
      name = "objectid"
      type = "string"
    }
    column {
      name = "keyid"
      type = "string"
    }
    column {
      name = "description"
      type = "string"
    }
    column {
      name = "TimeGenerated"
      type = "datetime"
    }
    column {
      name = "status"
      type = "string"
    }
    column {
      name = "owners"
      type = "string"
    }
  }

  description = "Data collection rule for credential cleanup"
  depends_on = [
    azapi_resource.workspaces_table_creds_cleanup_script,
    azurerm_monitor_data_collection_endpoint.data_collection_endpoint
  ]

  tags = local.tags
}

resource "azurerm_monitor_data_collection_rule" "data_collection_rule_AccessPackage" {
  name                        = "dcr-${var.department}-${var.team}-${var.project}-AccessPackage"
  location                    = var.location
  resource_group_name         = local.rg_name
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.data_collection_endpoint.id

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.log_analytics_workspace.id
      name                  = azurerm_log_analytics_workspace.log_analytics_workspace.name
    }
  }

  data_flow {
    streams       = ["Custom-${azapi_resource.workspaces_table_access_package_info.name}"]
    destinations  = [azurerm_log_analytics_workspace.log_analytics_workspace.name]
    transform_kql = "source"
    output_stream = "Custom-${azapi_resource.workspaces_table_access_package_info.name}"
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.managed_identity.id
    ]
  }

  stream_declaration {
    stream_name = "Custom-${azapi_resource.workspaces_table_access_package_info.name}"
    column {
      name = "AccessPackage"
      type = "string"
    }
    column {
      name = "AccessPackageID"
      type = "string"
    }
    column {
      name = "DisplayName"
      type = "string"
    }
    column {
      name = "Description"
      type = "string"
    }
    column {
      name = "ScopeType"
      type = "string"
    }
    column {
      name = "GroupID"
      type = "string"
    }
    column {
      name = "CatalogName"
      type = "string"
    }
    column {
      name = "RoleName"
      type = "string"
    }
    column {
      name = "RoleDescription"
      type = "string"
    }
    column {
      name = "AssignmentType"
      type = "string"
    }
    column {
      name = "RoleStatus"
      type = "string"
    }
    column {
      name = "ReviewerGroupName"
      type = "string"
    }
    column {
      name = "ReviewerGroupId"
      type = "string"
    }
    column {
      name = "TimeGenerated"
      type = "datetime"
    }
    column {
      name = "AccessReviewerGroupUsers"
      type = "string"
    }
    column {
      name = "NumberOfGroupMembers"
      type = "int"
    }

  }

  description = "Data collection rule for Access Package info"
  depends_on = [
    azapi_resource.workspaces_table_access_package_info,
    azurerm_monitor_data_collection_endpoint.data_collection_endpoint
  ]

  tags = local.tags
}

resource "azurerm_monitor_data_collection_rule" "data_collection_rule_guest_users" {
  name                        = "dcr-${var.department}-${var.team}-${var.project}-guest-users"
  location                    = var.location
  resource_group_name         = local.rg_name
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.data_collection_endpoint.id

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.log_analytics_workspace.id
      name                  = azurerm_log_analytics_workspace.log_analytics_workspace.name
    }
  }

  data_flow {
    streams       = ["Custom-${azapi_resource.workspaces_table_guest_users.name}"]
    destinations  = [azurerm_log_analytics_workspace.log_analytics_workspace.name]
    transform_kql = "source"
    output_stream = "Custom-${azapi_resource.workspaces_table_guest_users.name}"
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.managed_identity.id
    ]
  }

  stream_declaration {
    stream_name = "Custom-${azapi_resource.workspaces_table_guest_users.name}"
    column {
      name = "displayname"
      type = "string"
    }
    column {
      name = "objectid"
      type = "string"
    }
    column {
      name = "mail"
      type = "string"
    }
    column {
      name = "userPrincipleName"
      type = "string"
    }
    column {
      name = "accountEnabled"
      type = "boolean"
    }
    column {
      name = "createdDateTime"
      type = "datetime"
    }
    column {
      name = "externalUserState"
      type = "string"
    }
    column {
      name = "lastLoginDate"
      type = "datetime"
    }
    column {
      name = "hasLoggedIn"
      type = "boolean"
    }
    column {
      name = "daysSinceInvitedAndNotRegistered"
      type = "int"
    }
    column {
      name = "daysInactive"
      type = "int"
    }
    column {
      name = "isInactiveAfterPolicyDays"
      type = "boolean"
    }
    column {
      name = "isNotActivatedAfterPolicyDays"
      type = "boolean"
    }
    column {
      name = "isInactiveAfterExternalPolicyDays"
      type = "boolean"
    }
    column {
      name = "isNotActivatedAfterExternalPolicyDays"
      type = "boolean"
    }
    column {
      name = "TimeGenerated"
      type = "datetime"
    }
  }

  description = "Data collection rule for Guest Users"
  depends_on = [
    azapi_resource.workspaces_table_guest_users,
    azurerm_monitor_data_collection_endpoint.data_collection_endpoint
  ]

  tags = local.tags
}

resource "azurerm_monitor_data_collection_rule" "data_collection_rule_guest_del" {
  name                        = "dcr-${var.department}-${var.team}-${var.project}-guest-user-delete-cleanup"
  location                    = var.location
  resource_group_name         = local.rg_name
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.data_collection_endpoint.id

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.log_analytics_workspace.id
      name                  = azurerm_log_analytics_workspace.log_analytics_workspace.name
    }
  }

  data_flow {
    streams       = ["Custom-${azapi_resource.workspaces_table_guest_del_script.name}"]
    destinations  = [azurerm_log_analytics_workspace.log_analytics_workspace.name]
    transform_kql = "source"
    output_stream = "Custom-${azapi_resource.workspaces_table_guest_del_script.name}"
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.managed_identity.id
    ]
  }

  stream_declaration {
    stream_name = "Custom-${azapi_resource.workspaces_table_guest_del_script.name}"
    column {
      name = "id"
      type = "string"
    }
    column {
      name = "displayname"
      type = "string"
    }
    column {
      name = "userprincipalname"
      type = "string"
    }
    column {
      name = "createddatetime"
      type = "datetime"
    }
    column {
      name = "dayssincecreated"
      type = "int"
    }
    column {
      name = "lastlogindate"
      type = "datetime"
    }
    column {
      name = "daysinactive"
      type = "int"
    }
    column {
      name = "companyname"
      type = "string"
    }
    column {
      name = "jobtitle"
      type = "string"
    }
    column {
      name = "department"
      type = "string"
    }
    column {
      name = "cleanup"
      type = "string"
    }
    column {
      name = "deletetype"
      type = "string"
    }
    column {
      name = "TimeGenerated"
      type = "datetime"
    }
  }

  description = "Data collection rule for guest user deletion"
  depends_on = [
    azapi_resource.workspaces_table_guest_del_script,
    azurerm_monitor_data_collection_endpoint.data_collection_endpoint
  ]

  tags = local.tags
}
