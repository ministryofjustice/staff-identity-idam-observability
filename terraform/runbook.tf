data "local_file" "app_registrations_secrets_certs_script" {
  filename = "${path.module}/../scripts/ps/process-app-registration-secrets-certifiates.ps1"
}

resource "azurerm_automation_runbook" "runbook" {
  name                    = "${var.department}-${var.team}-${var.project}-runbook"
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
