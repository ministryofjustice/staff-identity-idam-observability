output "resource_group_name" {
  value = local.rg_name
}

output "managed_identity_client_id" {
  value = azurerm_user_assigned_identity.managed_identity.client_id
}

output "dceuri" {
  value = azurerm_monitor_data_collection_endpoint.data_collection_endpoint.logs_ingestion_endpoint
}

# Immutable IDs

output "dcr_immutable_id" {
  value = azurerm_monitor_data_collection_rule.data_collection_rule.immutable_id
}

output "dcr_immutable_cleanup_id" {
  value = azurerm_monitor_data_collection_rule.data_collection_rule_cleanup.immutable_id
}

output "dcr_immutable_accesspackage_id" {
  value = azurerm_monitor_data_collection_rule.data_collection_rule_AccessPackage.immutable_id
}

output "dcr_immutable_guest_users_id" {
  value = azurerm_monitor_data_collection_rule.data_collection_rule_guest_users.immutable_id
}

output "dcr_immutable_guest_del_id" {
  value = azurerm_monitor_data_collection_rule.data_collection_rule_guest_del.immutable_id
}

# Log Table Names

output "log_table_workspaces_table" {
  value = azapi_resource.workspaces_table.name
}

output "log_table_workspaces_table_access_package_info" {
  value = azapi_resource.workspaces_table_access_package_info.name
}

output "log_table_workspaces_table_creds_cleanup_script" {
  value = azapi_resource.workspaces_table_creds_cleanup_script.name
}

output "log_table_workspaces_table_guest_users" {
  value = azapi_resource.workspaces_table_guest_users.name
}

output "log_table_workspaces_table_guest_del_script" {
  value = azapi_resource.workspaces_table_guest_del_script.name
}

