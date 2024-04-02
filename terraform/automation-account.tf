resource "azurerm_automation_account" "automation_account" {
  name                = "${var.department}-${var.team}-${var.project}-managed-identity"
  location            = var.location
  resource_group_name = local.rg_name
  sku_name            = "Basic"

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.managed_identity.id
    ]
  }

  depends_on = [
    azurerm_user_assigned_identity.managed_identity,
  ]

  tags = local.tags
}

resource "azurerm_automation_schedule" "automation_schedule" {
  name                    = "${var.department}-${var.team}-${var.project}-automation-schedule"
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  frequency               = "Day"
  interval                = 1
  timezone                = "Europe/London"
  description             = "Run export daily."
}

resource "azurerm_automation_job_schedule" "example" {
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  schedule_name           = azurerm_automation_schedule.automation_schedule.name
  runbook_name            = azurerm_automation_runbook.runbook.name

  parameters = {
    miclientid     = azurerm_user_assigned_identity.managed_identity.id
    dcrimmutableid = azurerm_monitor_data_collection_rule.data_collection_rule.id
    logtablename   = azapi_resource.workspaces_table.name
    dceuri         = azurerm_monitor_data_collection_endpoint.data_collection_endpoint.logs_ingestion_endpoint
  }
}
