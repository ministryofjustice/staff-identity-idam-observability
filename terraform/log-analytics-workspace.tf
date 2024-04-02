resource "azurerm_log_analytics_workspace" "log_analytics_workspace" {
  name                = "${var.department}${var.team}${var.project}workspace"
  location            = var.location
  resource_group_name = local.rg_name

  tags = local.tags
}
