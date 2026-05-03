variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "uksouth"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-dab-prod-001"
}

# SQL

variable "sql_server_name" {
  description = "Name of the Azure SQL Server (must be globally unique)"
  type        = string
  default     = "sqlsvr-dab-prod-001"
}

variable "sql_database_name" {
  description = "Name of the Azure SQL Database"
  type        = string
  default     = "sqldb-dab-prod-001"
}

variable "sql_admin_username" {
  description = "SQL administrator login name"
  type        = string
  default     = "databaseadmin"
}

variable "sql_admin_password" {
  description = "SQL administrator password"
  type        = string
  sensitive   = true
}

variable "entra_admin_group_object_id" {
  description = "Object ID of the Entra group to set as SQL external admin (e.g. SQLAdmin group)"
  type        = string
}

variable "entra_admin_group_name" {
  description = "Display name of the Entra group used as SQL external admin"
  type        = string
  default     = "SQLAdmin"
}

# Storage

variable "storage_account_name" {
  description = "Name of the storage account (must be globally unique, lowercase, 3-24 chars)"
  type        = string
  default     = "dabconfigstorage001"
}

variable "file_share_name" {
  description = "Name of the Azure File Share holding dab-config.json"
  type        = string
  default     = "dab-config"
}

# Container

variable "container_name" {
  description = "Name of the Azure Container Instance running DAB"
  type        = string
  default     = "ci-dab-prod-001"
}

variable "container_dns_label" {
  description = "DNS label for the container instance (must be globally unique within the region)"
  type        = string
  default     = "ci-dab-prod-001"
}

variable "dab_image" {
  description = "DAB container image"
  type        = string
  default     = "mcr.microsoft.com/azure-databases/data-api-builder:latest"
}

# Function App

variable "function_app_name" {
  description = "Name of the Azure Function App"
  type        = string
  default     = "func-dab-prod-001"
}

variable "app_service_plan_name" {
  description = "Name of the consumption App Service Plan for the Function App"
  type        = string
  default     = "asp-dab-prod-001"
}
