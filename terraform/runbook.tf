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