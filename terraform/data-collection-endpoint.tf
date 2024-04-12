resource "azurerm_monitor_data_collection_endpoint" "data_collection_endpoint" {
  name                          = "dce-${var.department}-${var.team}-${var.project}"
  location                      = var.location
  resource_group_name           = local.rg_name
  kind                          = "Linux"
  public_network_access_enabled = true
  description                   = "Data Collection Endpoint"

  tags = local.tags
}
