resource "azurerm_resource_group" "resource_group" {
  location = var.location
  name     = "rg-${var.department}-${var.team}-${var.project}"

  tags = local.tags
}
