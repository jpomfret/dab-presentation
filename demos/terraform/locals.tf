locals {
  # Connection string uses Active Directory Default (MSI) auth so the container
  # can authenticate to SQL using its system-assigned managed identity.
  connection_string = "Server=tcp:${azurerm_mssql_server.dab.fully_qualified_domain_name},1433;Initial Catalog=${var.sql_database_name};Authentication=Active Directory Default;Encrypt=True;Connection Timeout=30;"

  # FQDN for the container instance API
  dab_endpoint = "http://${var.container_dns_label}.${var.location}.azurecontainer.io:5000"

  tenant_id = data.azuread_client_config.current.tenant_id
}
