terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~>1.12.1"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}

provider "azapi" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret

  default_tags     = local.tags
  default_location = azurerm_resource_group.resource_group.location
}

data "azurerm_subscription" "primary" {
}

locals {
  tags = {
    environment = var.environment
    department  = var.department
    source      = "terraform"
  }
}
