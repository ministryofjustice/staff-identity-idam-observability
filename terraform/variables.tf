variable "workspace_name" {
  type        = string
  description = "The name of the current workspace being run."

  validation {
    condition = contains([
      "DEVL",
      "NLE",
      "LIVE",
      "DEVLEXTERNAL",
      "NLEEXTERNAL",
      "LIVEEXTERNAL"
    ], var.workspace_name)
    error_message = "workspace_name must identify one of the six supported deployment environments."
  }
}

variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID."
}

variable "tenant_id" {
  type        = string
  description = "Azure Tenant ID."
}

variable "client_id" {
  type        = string
  description = "Client ID for authentication."
}

variable "project" {
  type        = string
  default     = "observability"
  description = "Short name for the project. Used for name prefixing of resources."
}

variable "location" {
  type        = string
  default     = "uksouth"
  description = "Azure region for resources to be deployed to."
}

variable "department" {
  type        = string
  default     = "eucs"
  description = "Department name."
}

variable "team" {
  type        = string
  default     = "idam"
  description = "Team Name."
}

variable "state_storage_account_name" {
  type        = string
  default     = "stidamobservetfstate"
  description = "Storage account name for TF state file."
}

variable "idam_email_recipient" {
  type        = string
  description = "Used as email recipient in scripts etc"
}

variable "idam_email_sender" {
  type        = string
  description = "Used as email sender in scripts etc"
}
