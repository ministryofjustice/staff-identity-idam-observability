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

