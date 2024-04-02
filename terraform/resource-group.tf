resource "azurerm_resource_group" "resource_group" {
  location = var.location
  name     = "rg-eucs-${var.project}-${var.environment}-resource-group"

  tags = local.tags
}
