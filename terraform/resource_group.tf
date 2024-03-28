resource "azurerm_resource_group" "resource_group" {
  location = var.location
  name     = "${var.project}-${var.environment}-resource-group"

  tags = local.tags
}
