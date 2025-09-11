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
  start_time              = "2025-09-12T07:00:00+01:00"
  description             = "Run export daily."
}

resource "azurerm_automation_schedule" "automation_schedule_cleanup" {
  name                    = "as-${var.department}-${var.team}-${var.project}-cleanup"
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  frequency               = "Day"
  interval                = 14
  timezone                = "Europe/London"
  start_time              = "2025-09-12T07:00:00+01:00"
  description             = "Run cleanup every 2 weeks."
}

resource "azurerm_automation_schedule" "automation_schedule_guest_users" {
  name                    = "as-${var.department}-${var.team}-${var.project}-guest-users"
  resource_group_name     = local.rg_name
  automation_account_name = azurerm_automation_account.automation_account.name
  frequency               = "Day"
  interval                = 1
  timezone                = "Europe/London"
  start_time              = "2025-09-12T07:00:00+01:00"
  description             = "Run export daily."
}
