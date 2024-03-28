resource "azurerm_monitor_data_collection_endpoint" "data_collection_endpoint" {
  name                          = "${var.project}-${var.environment}-mdce"
  location                      = azurerm_resource_group.resource_group.location
  resource_group_name           = azurerm_resource_group.resource_group.name
  kind                          = "Linux"
  public_network_access_enabled = false
  description                   = "Data Collection Endpoint"

  tags = local.tags
}
