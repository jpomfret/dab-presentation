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

  # Basic (5 DTU) — cheapest available tier, ~$5/month
  sku_name = "Basic"

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

# Fetch the public IP of the machine running terraform so the local-exec
# provisioner below can reach the SQL server.
data "external" "deployer_ip" {
  program = ["PowerShell", "-Command", "Write-Output ('{\"ip\":\"' + (Invoke-RestMethod -Uri 'https://checkip.amazonaws.com').Trim() + '\"}')" ]
}

resource "azurerm_mssql_firewall_rule" "deployer_ip" {
  name             = "DeployerIP"
  server_id        = azurerm_mssql_server.dab.id
  start_ip_address = data.external.deployer_ip.result.ip
  end_ip_address   = data.external.deployer_ip.result.ip
}

# Grant the container instance's managed identity read/write access.
# This must run after the container (and its MI) is created and requires
# an active az CLI session authenticated with the Entra admin account.
resource "null_resource" "container_db_user" {
  depends_on = [
    azurerm_container_group.dab,
    azurerm_mssql_database.dab,
    azurerm_mssql_firewall_rule.allow_azure_services,
    azurerm_mssql_firewall_rule.deployer_ip,
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

# Create the Intervals.icu tables that IntervalsSync writes to.
# Re-runs only if the database is recreated (tracked by database id).
resource "null_resource" "intervals_tables" {
  depends_on = [
    azurerm_mssql_database.dab,
    azurerm_mssql_firewall_rule.allow_azure_services,
    azurerm_mssql_firewall_rule.deployer_ip,
    null_resource.container_db_user,
  ]

  triggers = {
    database_id          = azurerm_mssql_database.dab.id
    wellness_sp_hash     = filemd5("${path.module}/templates/usp_UpsertWellness.sql")
    activity_sp_hash     = filemd5("${path.module}/templates/usp_UpsertActivity.sql")
    logsync_sp_hash      = filemd5("${path.module}/templates/usp_LogSync.sql")
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'Stop'
      $token  = (az account get-access-token --resource https://database.windows.net | ConvertFrom-Json).accessToken
      $server = "${azurerm_mssql_server.dab.fully_qualified_domain_name}"
      $db     = "${var.sql_database_name}"

      Invoke-Sqlcmd -ServerInstance $server -Database $db -AccessToken $token -Query "IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'IntervalsWellness' AND schema_id = SCHEMA_ID('dbo')) BEGIN CREATE TABLE dbo.IntervalsWellness (RecordDate date NOT NULL, CTL float NULL, ATL float NULL, TSB float NULL, RampRate float NULL, CTLLoad float NULL, ATLLoad float NULL, Weight float NULL, RestingHR int NULL, HRV float NULL, SleepSecs int NULL, SleepScore float NULL, SleepQuality nvarchar(50) NULL, Form nvarchar(50) NULL, Updated datetime2 NULL, InsertedAt datetime2 NOT NULL DEFAULT GETUTCDATE(), CONSTRAINT PK_IntervalsWellness PRIMARY KEY (RecordDate)) END"

      Invoke-Sqlcmd -ServerInstance $server -Database $db -AccessToken $token -Query "IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'IntervalsActivity' AND schema_id = SCHEMA_ID('dbo')) BEGIN CREATE TABLE dbo.IntervalsActivity (ActivityId nvarchar(50) NOT NULL, StartDateLocal datetime2 NULL, ActivityType nvarchar(50) NULL, ActivityName nvarchar(500) NULL, MovingTime int NULL, Distance float NULL, TrainingLoad float NULL, ATLLoad float NULL, CTLLoad float NULL, Intensity float NULL, AverageWatts float NULL, AverageHeartrate float NULL, TotalElevationGain float NULL, CTL float NULL, ATL float NULL, InsertedAt datetime2 NOT NULL DEFAULT GETUTCDATE(), CONSTRAINT PK_IntervalsActivity PRIMARY KEY (ActivityId)) END"

      Invoke-Sqlcmd -ServerInstance $server -Database $db -AccessToken $token -InputFile "${path.module}/templates/usp_UpsertWellness.sql"
      Invoke-Sqlcmd -ServerInstance $server -Database $db -AccessToken $token -InputFile "${path.module}/templates/usp_UpsertActivity.sql"
      Invoke-Sqlcmd -ServerInstance $server -Database $db -AccessToken $token -InputFile "${path.module}/templates/usp_LogSync.sql"

      # Grant the DAB container MI EXECUTE on the stored procedures
      Invoke-Sqlcmd -ServerInstance $server -Database $db -AccessToken $token -Query "GRANT EXECUTE ON dbo.usp_UpsertWellness TO [${var.container_name}]; GRANT EXECUTE ON dbo.usp_UpsertActivity TO [${var.container_name}]; GRANT EXECUTE ON dbo.usp_LogSync TO [${var.container_name}];"

      Write-Host "Intervals tables and stored procedures created."
    EOT
  }
}

# Create the FuelGaugeCalories table and stored procedure.
# Re-runs if the SP file changes or the database is recreated.
resource "null_resource" "fuelgauge_calories" {
  depends_on = [
    null_resource.intervals_tables,
  ]

  triggers = {
    database_id          = azurerm_mssql_database.dab.id
    calories_sp_hash     = filemd5("${path.module}/templates/usp_UpsertCalories.sql")
    calorie_burn_sp_hash = filemd5("${path.module}/templates/usp_UpsertCalorieBurn.sql")
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'Stop'
      $token  = (az account get-access-token --resource https://database.windows.net | ConvertFrom-Json).accessToken
      $server = "${azurerm_mssql_server.dab.fully_qualified_domain_name}"
      $db     = "${var.sql_database_name}"

      Invoke-Sqlcmd -ServerInstance $server -Database $db -AccessToken $token -InputFile "${path.module}/templates/usp_UpsertCalories.sql"
      Invoke-Sqlcmd -ServerInstance $server -Database $db -AccessToken $token -InputFile "${path.module}/templates/usp_UpsertCalorieBurn.sql"

      # Grant the DAB container MI EXECUTE on both stored procedures
      Invoke-Sqlcmd -ServerInstance $server -Database $db -AccessToken $token -Query "GRANT EXECUTE ON dbo.usp_UpsertCalories TO [${var.container_name}]; GRANT EXECUTE ON dbo.usp_UpsertCalorieBurn TO [${var.container_name}];"

      Write-Host "FuelGaugeCalories and FuelGaugeCalorieBurn tables and stored procedures created."
    EOT
  }
}
