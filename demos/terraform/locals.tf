locals {
  # Connection string uses Active Directory Default (MSI) auth so the container
  # can authenticate to SQL using its system-assigned managed identity.
  connection_string = "Server=tcp:${azurerm_mssql_server.dab.fully_qualified_domain_name},1433;Initial Catalog=${var.sql_database_name};Authentication=Active Directory Default;Encrypt=True;Connection Timeout=30;"

  # HTTPS endpoint — used by the browser (static web app) and the DAB swagger URL
  dab_endpoint = "https://${azurerm_container_app.dab.ingress[0].fqdn}"

  # HTTP endpoint — used by the function app so Invoke-RestMethod uses plain
  # HTTP/1.1 and avoids TLS ALPN negotiation that causes InvalidOperationException
  dab_endpoint_http = "http://${azurerm_container_app.dab.ingress[0].fqdn}"

  tenant_id = data.azuread_client_config.current.tenant_id
}
