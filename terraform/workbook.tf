resource "azurerm_application_insights_workbook" "application_insights_workbook" {
  name                = "8eaea574-6ad6-407b-b5a0-4a9ba9b78e5b"
  resource_group_name = local.rg_name
  location            = var.location
  display_name        = "Secrets and Certificate Expiration"

  data_json = templatefile("${path.module}/../scripts/workbooks/azure-secret-certificate-notification-logs.json",
    {
      resourceGroup  = local.rg_name,
      workspaceName  = azurerm_log_analytics_workspace.log_analytics_workspace.name
      tableName      = azapi_resource.workspaces_table.name,
      subscriptionId = var.subscription_id
  })

  tags = local.tags
}
