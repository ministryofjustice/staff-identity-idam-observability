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
  start_time              = "2025-10-02T07:00:00+01:00"
  description             = "Run daily application registration credential report."
}

resource "azurerm_automation_job_schedule" "automation_job_schedule" {
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  runbook_name            = azurerm_automation_runbook.runbook.name
  schedule_name           = azurerm_automation_schedule.automation_schedule.name
  parameters = {
    miclientid     = azurerm_user_assigned_identity.managed_identity.client_id,
    dcrimmutableid = azurerm_monitor_data_collection_rule.data_collection_rule.immutable_id,
    dceuri         = azurerm_monitor_data_collection_endpoint.data_collection_endpoint.logs_ingestion_endpoint,
    logtablename   = azapi_resource.workspaces_table.name
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
  start_time              = "2025-10-02T07:00:00+01:00"
  description             = "Run Guest User reporting daily."
}

resource "azurerm_automation_job_schedule" "automation_job_schedule_guest_users" {
  count = var.workspace_name == "DEVLEXTERNAL" || var.workspace_name == "LIVE" || var.workspace_name == "LIVEEXTERNAL" ? 1 : 0

  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  runbook_name            = azurerm_automation_runbook.runbook_guest_users_script.name
  schedule_name           = azurerm_automation_schedule.automation_schedule_guest_users.name
  parameters = {
    miclientid     = azurerm_user_assigned_identity.managed_identity.client_id,
    dcrimmutableid = azurerm_monitor_data_collection_rule.data_collection_rule_guest_users.immutable_id,
    dceuri         = azurerm_monitor_data_collection_endpoint.data_collection_endpoint.logs_ingestion_endpoint,
    logtablename   = azapi_resource.workspaces_table_guest_users.name
  }
}

resource "azurerm_automation_schedule" "automation_schedule_Access_Package" {
  name                    = "as-${var.department}-${var.team}-${var.project}-access-package"
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  frequency               = "Day"
  interval                = 1
  timezone                = "Europe/London"
  start_time              = "2025-10-02T07:00:00+01:00"
  description             = "Run AccessPackage runbook daily."
}

resource "azurerm_automation_job_schedule" "automation_job_schedule_Access_Package" {
  count = var.workspace_name == "LIVE" ? 1 : 0

  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  runbook_name            = azurerm_automation_runbook.runbook_Access_Package_info_script.name
  schedule_name           = azurerm_automation_schedule.automation_schedule_Access_Package.name
  parameters = {
    miclientid     = azurerm_user_assigned_identity.managed_identity.client_id,
    dcrimmutableid = azurerm_monitor_data_collection_rule.data_collection_rule_AccessPackage.immutable_id,
    dceuri         = azurerm_monitor_data_collection_endpoint.data_collection_endpoint.logs_ingestion_endpoint,
    logtablename   = azapi_resource.workspaces_table_access_package_info.name
  }
}

resource "azurerm_automation_schedule" "automation_schedule_guest_del" {
  name                    = "as-${var.department}-${var.team}-${var.project}-guest-del"
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  frequency               = "Day"
  interval                = 1
  timezone                = "Europe/London"
  start_time              = "2025-10-02T07:00:00+01:00"
  description             = "Run Guest User Delete every day."
}

resource "azurerm_automation_job_schedule" "automation_job_schedule_guest_del" {
  count = var.workspace_name == "DEVL" ? 1 : 0

  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  runbook_name            = azurerm_automation_runbook.runbook_guest_del_devl.name
  schedule_name           = azurerm_automation_schedule.automation_schedule_guest_del.name
  parameters = {
    miclientid     = azurerm_user_assigned_identity.managed_identity.client_id,
    dcrimmutableid = azurerm_monitor_data_collection_rule.data_collection_rule_guest_del.immutable_id,
    dceuri         = azurerm_monitor_data_collection_endpoint.data_collection_endpoint.logs_ingestion_endpoint,
    logtablename   = azapi_resource.workspaces_table_guest_del_script.name
  }
}
