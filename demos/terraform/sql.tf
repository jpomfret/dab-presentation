resource "azurerm_mssql_server" "dab" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.dab.name
  location                     = azurerm_resource_group.dab.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password

  # Entra group as external admin — required so we can later CREATE USER
  # [container-mi] FROM EXTERNAL PROVIDER using an Entra-authenticated session.
  azuread_administrator {
    login_username              = var.entra_admin_group_name
    object_id                   = var.entra_admin_group_object_id
    azuread_authentication_only = false
  }
}

resource "azurerm_mssql_database" "dab" {
  name      = var.sql_database_name
  server_id = azurerm_mssql_server.dab.id

  # Serverless GP Gen5 2 vCores — matches the blog's CLI parameters
  sku_name                    = "GP_S_Gen5_2"
  auto_pause_delay_in_minutes = 60
  min_capacity                = 0.5

  # Seed with AdventureWorksLT for the demo entities
  sample_name = "AdventureWorksLT"
}

# Allow all Azure-internal traffic (start/end 0.0.0.0) so the container
# instance and Function App can reach the database.
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.dab.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Grant the container instance's managed identity read/write access.
# This must run after the container (and its MI) is created and requires
# an active az CLI session authenticated with the Entra admin account.
resource "null_resource" "container_db_user" {
  depends_on = [
    azurerm_container_group.dab,
    azurerm_mssql_database.dab,
    azurerm_mssql_firewall_rule.allow_azure_services,
  ]

  triggers = {
    container_identity = azurerm_container_group.dab.identity[0].principal_id
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'Stop'
      $token = (az account get-access-token --resource https://database.windows.net | ConvertFrom-Json).accessToken
      $query = "IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = '${var.container_name}') BEGIN CREATE USER [${var.container_name}] FROM EXTERNAL PROVIDER; ALTER ROLE db_datareader ADD MEMBER [${var.container_name}]; ALTER ROLE db_datawriter ADD MEMBER [${var.container_name}]; END"
      Invoke-Sqlcmd -ServerInstance "${azurerm_mssql_server.dab.fully_qualified_domain_name}" -Database "${var.sql_database_name}" -AccessToken $token -Query $query
      Write-Host "Database user '${var.container_name}' provisioned."
    EOT
  }
}
