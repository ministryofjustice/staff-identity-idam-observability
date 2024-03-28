resource "azurerm_log_analytics_workspace" "log_analytics_workspace" {
  name                = "${var.project}${var.environment}workspace"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  tags = local.tags
}
