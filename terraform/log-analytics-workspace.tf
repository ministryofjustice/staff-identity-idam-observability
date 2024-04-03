resource "azurerm_log_analytics_workspace" "log_analytics_workspace" {
  name                = "log-${var.department}${var.team}${var.project}"
  location            = var.location
  resource_group_name = local.rg_name

  tags = local.tags
}
