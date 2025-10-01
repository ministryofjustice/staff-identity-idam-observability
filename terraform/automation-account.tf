resource "azurerm_automation_account" "automation_account" {
  name                = "aa-${var.department}-${var.team}-${var.project}"
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
  name                    = "as-${var.department}-${var.team}-${var.project}"
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  frequency               = "Day"
  interval                = 1
  timezone                = "Europe/London"
  start_time              = "2025-10-01T07:00:00+01:00"
  description             = "Run export daily."
}

resource "azurerm_automation_job_schedule" "automation_job_schedule" {
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  runbook_name            = azurerm_automation_runbook.runbook.name
  schedule_name           = azurerm_automation_schedule.automation_schedule.name
  parameters = { 
    MiClientId     = azurerm_user_assigned_identity.managed_identity.client_id,
    DcrImmutableId = azurerm_monitor_data_collection_rule.data_collection_rule.immutable_id,
    DceUri         = azurerm_monitor_data_collection_endpoint.data_collection_endpoint.logs_ingestion_endpoint,
    LogTableName   = azapi_resource.workspaces_table.name
  }
}

resource "azurerm_automation_schedule" "automation_schedule_cleanup" {
  name                    = "as-${var.department}-${var.team}-${var.project}-cleanup"
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  frequency               = "Day"
  interval                = 14
  timezone                = "Europe/London"
  start_time              = "2025-09-16T07:00:00+01:00"
  description             = "Run cleanup every 2 weeks."
}

resource "azurerm_automation_schedule" "automation_schedule_guest_users" {
  name                    = "as-${var.department}-${var.team}-${var.project}-guest-users"
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  frequency               = "Day"
  interval                = 1
  timezone                = "Europe/London"
  start_time              = "2025-09-16T07:00:00+01:00"
  description             = "Run export daily."
}

resource "azurerm_automation_schedule" "automation_schedule_Access_Package" {
  name                    = "as-${var.department}-${var.team}-${var.project}-access-package"
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  frequency               = "Day"
  interval                = 14
  timezone                = "Europe/London"
  start_time              = "2025-09-16T07:00:00+01:00"
  description             = "Run AccessPackage runbook every 2 weeks."
}

resource "azurerm_automation_schedule" "automation_schedule_guest_del" {
  name                    = "as-${var.department}-${var.team}-${var.project}-guest-del"
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  frequency               = "Day"
  interval                = 1
  timezone                = "Europe/London"
  start_time              = "2025-09-26T07:00:00+01:00"
  description             = "Run Guest User Delete every day."
}
