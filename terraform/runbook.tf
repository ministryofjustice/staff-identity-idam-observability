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

data "local_file" "user_metrics" {
  filename = "${path.module}/../scripts/ps/get-user-metrics.ps1"
}

resource "azurerm_automation_runbook" "runbook_user_metrics" {
  name                    = "rb-${var.department}-${var.team}-${var.project}-user-metrics-script"
  location                = var.location
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Retrieves user metrics."
  runbook_type            = "PowerShell72"

  content = data.local_file.user_metrics.content

  tags = local.tags
}

data "local_file" "T1Roles" {
  filename = "${path.module}/../scripts/ps/Get-Tier1PermAssignedRoles.ps1"
}

resource "azurerm_automation_runbook" "runbook_T1_Permusers_script" {
  name                    = "rb-${var.department}-${var.team}-${var.project}-Get-T1-Perm-Roles-script"
  location                = var.location
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Excract's users that have T1 roles permanently assigned to them"
  runbook_type            = "PowerShell72"

  content = data.local_file.T1Roles.content

  tags = local.tags
}

data "local_file" "app_metrics" {
  filename = "${path.module}/../scripts/ps/get-app-metrics.ps1"
}

resource "azurerm_automation_runbook" "runbook_app_metrics" {
  name                    = "rb-${var.department}-${var.team}-${var.project}-app-metrics-script"
  location                = var.location
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Retrieves app metrics."
  runbook_type            = "PowerShell72"

  content = data.local_file.app_metrics.content

  tags = local.tags
}
