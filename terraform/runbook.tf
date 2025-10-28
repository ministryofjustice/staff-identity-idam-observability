data "local_file" "app_registrations_secrets_certs_script" {
  filename = "${path.module}/../scripts/ps/process-app-registration-secrets-certifiates.ps1"
}

resource "azurerm_automation_runbook" "runbook" {
  name                    = "rb-${var.department}-${var.team}-${var.project}"
  location                = var.location
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Extracts App Registration Secret and Certificate expiration details."
  runbook_type            = "PowerShell72"

  content = data.local_file.app_registrations_secrets_certs_script.content

  tags = local.tags
}

data "local_file" "app_registrations_creds_cleanup_script" {
  filename = "${path.module}/../scripts/ps/process-app-registration-creds-cleanup.ps1"
}

resource "azurerm_automation_runbook" "runbook_creds_cleanup_script" {
  name                    = "rb-${var.department}-${var.team}-${var.project}-creds-cleanup-script"
  location                = var.location
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Cleans up expired App Registration credentials."
  runbook_type            = "PowerShell72"

  content = data.local_file.app_registrations_creds_cleanup_script.content

  tags = local.tags
}

data "local_file" "Access_Package_info_script" {
  filename = "${path.module}/../scripts/ps/Get-AccessPackage.ps1"
}

resource "azurerm_automation_runbook" "runbook_Access_Package_info_script" {
  name                    = "rb-${var.department}-${var.team}-${var.project}-AccessPackage-info"
  location                = var.location
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Extracts details from MSGraph about Access package owners, roles and reviewers."
  runbook_type            = "PowerShell72"

  content = data.local_file.Access_Package_info_script.content

  tags = local.tags
}

data "local_file" "app_registrations_guest_users_script" {
  filename = "${path.module}/../scripts/ps/process-guest-users.ps1"
}

resource "azurerm_automation_runbook" "runbook_guest_users_script" {
  name                    = "rb-${var.department}-${var.team}-${var.project}-guest-users-script"
  location                = var.location
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Extracts Guest User details."
  runbook_type            = "PowerShell72"

  content = data.local_file.app_registrations_guest_users_script.content

  tags = local.tags
}

data "local_file" "app_registrations_guest_del_devl" {
  filename = "${path.module}/../scripts/ps/process-guest-user-delete-devl.ps1"
}

resource "azurerm_automation_runbook" "runbook_guest_del_devl" {
  name                    = "rb-${var.department}-${var.team}-${var.project}-guest-del-script"
  location                = var.location
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Deletes guest users within certain parameters."
  runbook_type            = "PowerShell72"

  content = data.local_file.app_registrations_guest_del_devl.content

  tags = local.tags
}

data "local_file" "mfa_metrics" {
  filename = "${path.module}/../scripts/ps/get-mfa-metrics.ps1"
}

resource "azurerm_automation_runbook" "runbook_mfa_metrics" {
  name                    = "rb-${var.department}-${var.team}-${var.project}-mfa-metrics-script"
  location                = var.location
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Retrieves MFA metrics."
  runbook_type            = "PowerShell72"

  content = data.local_file.mfa_metrics.content

  tags = local.tags
}
