resource "azurerm_user_assigned_identity" "managed_identity" {
  name                = "mi-${var.department}-${var.team}-${var.project}"
  location            = var.location
  resource_group_name = local.rg_name

  tags = local.tags
}

resource "azurerm_role_assignment" "assign_identity_automation_account_global_reader" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.managed_identity.principal_id

  depends_on = [
    azurerm_user_assigned_identity.managed_identity,
  ]
}

resource "azurerm_role_assignment" "assign_identity_dcr_monitoring_publisher" {
  scope                = azurerm_monitor_data_collection_rule.data_collection_rule.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.managed_identity.principal_id

  depends_on = [
    azurerm_user_assigned_identity.managed_identity,
    azurerm_automation_account.automation_account,
  ]
}

resource "azurerm_role_assignment" "assign_identity_dcr_cleanup_monitoring_publisher" {
  scope                = azurerm_monitor_data_collection_rule.data_collection_rule_cleanup.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.managed_identity.principal_id

  depends_on = [
    azurerm_user_assigned_identity.managed_identity,
    azurerm_automation_account.automation_account,
  ]
}

resource "azurerm_role_assignment" "assign_identity_dcr_guest_users_monitoring_publisher" {
  scope                = azurerm_monitor_data_collection_rule.data_collection_rule_guest_users.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.managed_identity.principal_id

  depends_on = [
    azurerm_user_assigned_identity.managed_identity,
    azurerm_automation_account.automation_account,
  ]
}

resource "azurerm_role_assignment" "assign_identity_dcr_Access_package_monitoring_publisher" {
  scope                = azurerm_monitor_data_collection_rule.data_collection_rule_AccessPackage.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.managed_identity.principal_id

  depends_on = [
    azurerm_user_assigned_identity.managed_identity,
    azurerm_automation_account.automation_account,
  ]
}

## Custom role not created in code as the pipeline does not have permissions
## We didn't want to create elevated permissions on the pipeline for  just for this one item
#resource "azuread_custom_directory_role" "assign_identity_automation_account_application_update" {
#  display_name = "Application Credentials Updater"
#  description  = "Used to allow the IdAM Managed Identity to update app registration credentials."
#  enabled      = true
#  version      = "1.0"
#
#  permissions {
#    allowed_resource_actions = ["microsoft.directory/applications/credentials/update"]
#  }
#}

resource "azurerm_role_assignment" "assign_identity_dcr_mfa_metrics_monitoring_publisher" {
  scope                = azurerm_monitor_data_collection_rule.data_collection_rule_mfa_metrics.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.managed_identity.principal_id

  depends_on = [
    azurerm_user_assigned_identity.managed_identity,
    azurerm_automation_account.automation_account,
  ]
}

resource "azurerm_role_assignment" "assign_identity_dcr_user_metrics_monitoring_publisher" {
  scope                = azurerm_monitor_data_collection_rule.data_collection_rule_user_metrics.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.managed_identity.principal_id

  depends_on = [
    azurerm_user_assigned_identity.managed_identity,
    azurerm_automation_account.automation_account,
  ]
}
