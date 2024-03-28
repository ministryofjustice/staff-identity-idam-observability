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

variable "client_secret" {
  type        = string
  description = "Client Secret for authentication."
}

variable "project" {
  type        = string
  default     = "idamobs"
  description = "Short name for the project. Used for name prefixing of resources."
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment short name. Used for tags."
}

variable "location" {
  type        = string
  default     = "uksouth"
  description = "Azure region for resources to be deployed to."
}

variable "department" {
  type        = string
  default     = "eucsidam"
  description = "Azure region for resources to be deployed to."
}
