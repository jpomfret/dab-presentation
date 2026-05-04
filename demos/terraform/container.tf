resource "azurerm_container_group" "dab" {
  name                = var.container_name
  resource_group_name = azurerm_resource_group.dab.name
  location            = azurerm_resource_group.dab.location
  ip_address_type     = "Public"
  dns_name_label      = var.container_dns_label
  os_type             = "Linux"
  sku                 = "Standard"

  # System-assigned MI used to authenticate to Azure SQL Database
  identity {
    type = "SystemAssigned"
  }

  container {
    name   = "dab"
    image  = var.dab_image
    cpu    = "1"
    memory = "1.5"

    ports {
      port     = 5000
      protocol = "TCP"
    }

    environment_variables = {
      DATABASE_CONNECTION_STRING = local.connection_string
    }

    # Mount the file share so DAB can read /cfg/dab-config.json
    volume {
      name                 = "dab-config"
      mount_path           = "/cfg"
      share_name           = azurerm_storage_share.dab.name
      storage_account_name = azurerm_storage_account.dab.name
      storage_account_key  = azurerm_storage_account.dab.primary_access_key
    }

    commands = [
      "dotnet",
      "Azure.DataApiBuilder.Service.dll",
      "--ConfigFileName",
      "/cfg/dab-config.json",
    ]
  }

  depends_on = [null_resource.upload_dab_config]
}

# Restart the container after the SQL database user is provisioned so it can
# start in a healthy state with full database access. Also restarts when the
# DAB config template changes so new permissions/entities take effect.
resource "null_resource" "restart_container" {
  depends_on = [
    null_resource.container_db_user,
    null_resource.upload_dab_config,
  ]

  triggers = {
    container_db_user = null_resource.container_db_user.id
    config_hash       = null_resource.upload_dab_config.id
  }

  provisioner "local-exec" {
    command = "az container restart --resource-group ${var.resource_group_name} --name ${var.container_name}"
  }
}
