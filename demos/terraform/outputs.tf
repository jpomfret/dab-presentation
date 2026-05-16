output "resource_group_name" {
  description = "Resource group containing all DAB infrastructure"
  value       = azurerm_resource_group.dab.name
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the Azure SQL Server"
  value       = azurerm_mssql_server.dab.fully_qualified_domain_name
}

output "dab_api_endpoint" {
  description = "Base URL for the DAB REST API"
  value       = "${local.dab_endpoint}/api"
}

output "dab_swagger_url" {
  description = "Swagger UI for the DAB API (development mode only)"
  value       = "${local.dab_endpoint}/swagger"
}

output "function_app_hostname" {
  description = "Default hostname of the Azure Function App"
  value       = azurerm_windows_function_app.dab.default_hostname
}

output "function_app_identity_principal_id" {
  description = "Object ID of the Function App's system-assigned managed identity"
  value       = azurerm_windows_function_app.dab.identity[0].principal_id
}

output "app_insights_connection_string" {
  description = "Application Insights connection string for the Function App"
  value       = azurerm_application_insights.dab.connection_string
  sensitive   = true
}

output "dashboard_url" {
  description = "URL of the Chase the Sun training dashboard"
  value       = "https://${azurerm_static_web_app.dashboard.default_host_name}"
}

output "container_identity_principal_id" {
  description = "Object ID of the Container App's system-assigned managed identity"
  value       = azurerm_container_app.dab.identity[0].principal_id
}

output "app_registration_client_id" {
  description = "Client (app) ID of the DAB-API-Access Entra app registration"
  value       = azuread_application.dab_api.client_id
}

output "app_registration_identifier_uri" {
  description = "Identifier URI of the app registration — used as the token audience in dab-config.json"
  value       = "api://${azuread_application.dab_api.client_id}"
}

output "tenant_id" {
  description = "Entra tenant ID — used as the token issuer in dab-config.json"
  value       = local.tenant_id
}

output "storage_account_name" {
  description = "Name of the storage account holding dab-config.json"
  value       = azurerm_storage_account.dab.name
}

output "get_user_token_command" {
  description = "PowerShell command to get a user token for testing the DAB API"
  value       = "az account get-access-token --resource 'api://${azuread_application.dab_api.client_id}' | ConvertFrom-Json | Select-Object -ExpandProperty accessToken"
}

output "dashboard_url_pub" {
  description = "Public URL for the training dashboard (custom domain if configured, otherwise SWA default)"
  value       = var.dashboard_custom_domain != "" ? "https://${var.dashboard_custom_domain}" : "https://${azurerm_static_web_app.dashboard.default_host_name}"
}
