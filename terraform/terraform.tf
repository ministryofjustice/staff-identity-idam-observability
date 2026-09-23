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
  backend "azurerm" {
    resource_group_name  = "rg-eucs-idam-observability"
    storage_account_name = "stidamobservetfstate003"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  use_oidc        = true
}

provider "azapi" {
  subscription_id  = var.subscription_id
  tenant_id        = var.tenant_id
  client_id        = var.client_id
  use_oidc         = true
  default_tags     = local.tags
  default_location = var.location
}

data "azurerm_subscription" "primary" {
}

locals {
  rg_name = "rg-${var.department}-${var.team}-${var.project}"

  common_tags = {
    application        = "IDAM Observability"
    businessarea       = "DISO IdAM"
    dataclassification = null
    department         = var.department
    infracontact       = "IDAM@justice.gov.uk"
    owner              = "DISO IdAM"
    project            = var.project
    source             = "terraform"
    team               = var.team
  }

  workspace_tags = {
    DEVL = {
      environment = "Development"
      purchaseorder      = "23070053085"
    }
    NLE = {
      environment = "NLE"
      purchaseorder      = "23070053085"
    }
    LIVE = {
      environment = "Production"
      purchaseorder      = "23070053085"
    }
    DEVLEXTERNAL = {
      environment = "devl"
      purchaseorder      = "23070053075"
    }
    NLEEXTERNAL = {
      environment = "prep"
      purchaseorder      = "23070053075"
    }
    LIVEEXTERNAL = {
      environment = "prod"
      purchaseorder      = "23070053075"
    }
  }

  tags = merge(local.common_tags, local.workspace_tags[var.workspace_name])
}
