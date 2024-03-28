resource "azurerm_monitor_data_collection_rule" "data_collection_rule" {
  name                        = "${var.project}-${var.environment}-dcrule"
  location                    = azurerm_resource_group.resource_group.location
  resource_group_name         = azurerm_resource_group.resource_group.name
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.data_collection_endpoint.id

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.log_analytics_workspace.id
      name                  = azurerm_log_analytics_workspace.log_analytics_workspace.name
      #name                  = "${var.project}-${var.environment}-log"
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
  }

  description = "Data collection rule"
  depends_on = [
    azapi_resource.workspaces_table,
    azurerm_monitor_data_collection_endpoint.data_collection_endpoint
  ]

  tags = local.tags
}
