output "resource_group_name" {
  value = local.rg_name
}

output "client_id" {
  value = azurerm_user_assigned_identity.managed_identity.client_id
}

output "logs_ingestion_endpoint" {
  value = azurerm_monitor_data_collection_endpoint.data_collection_endpoint.logs_ingestion_endpoint
}

output "configuration_access_endpoint" {
  value = azurerm_monitor_data_collection_endpoint.data_collection_endpoint.configuration_access_endpoint
}

output "dcr_id" {
  value = azurerm_monitor_data_collection_rule.data_collection_rule.id
}

output "dcr_immutable_id" {
  value = azurerm_monitor_data_collection_rule.data_collection_rule.immutable_id
}

output "workspace_table_name" {
  value = azapi_resource.workspaces_table.name
}