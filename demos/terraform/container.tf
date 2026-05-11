# Log Analytics workspace — required by Container App Environment for log shipping.
resource "azurerm_log_analytics_workspace" "dab" {
  name                = "law-dab-prod-001"
  resource_group_name = azurerm_resource_group.dab.name
  location            = azurerm_resource_group.dab.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Container App Environment — the shared runtime boundary for our container.
# Provisioned with a public, zone-redundant ingress so the Container App gets
# a stable HTTPS hostname with TLS termination handled for us.
resource "azurerm_container_app_environment" "dab" {
  name                       = var.container_app_environment_name
  resource_group_name        = azurerm_resource_group.dab.name
  location                   = azurerm_resource_group.dab.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.dab.id
}

# Register the existing Azure Files share with the environment so containers
# can mount it as a volume.
resource "azurerm_container_app_environment_storage" "dab_config" {
  name                         = "dab-config"
  container_app_environment_id = azurerm_container_app_environment.dab.id
  account_name                 = azurerm_storage_account.dab.name
  share_name                   = azurerm_storage_share.dab.name
  access_key                   = azurerm_storage_account.dab.primary_access_key
  access_mode                  = "ReadOnly"
}

# DAB Container App.
# External ingress gives a stable *.azurecontainerapps.io HTTPS endpoint —
# TLS is terminated by the environment, DAB only ever speaks HTTP internally.
resource "azurerm_container_app" "dab" {
  name                         = var.container_name
  container_app_environment_id = azurerm_container_app_environment.dab.id
  resource_group_name          = azurerm_resource_group.dab.name
  revision_mode                = "Single"

  # System-assigned MI — used by DAB to authenticate to Azure SQL with
  # Active Directory Default (no password in the connection string).
  identity {
    type = "SystemAssigned"
  }

  # External HTTPS ingress on the standard port (443).
  # Container Apps terminates TLS; DAB listens on 5000 internally.
  ingress {
    external_enabled = true
    target_port      = 5000
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Storage key passed as a secret so it isn't in plain text in the template.
  secret {
    name  = "storage-account-key"
    value = azurerm_storage_account.dab.primary_access_key
  }

  template {
    container {
      name   = "dab"
      image  = var.dab_image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "DATABASE_CONNECTION_STRING"
        value = local.connection_string
      }

      # Changing this env var forces a new revision (= restart) whenever the
      # DAB config file is re-uploaded to the file share.
      env {
        name  = "DAB_CONFIG_VERSION"
        value = null_resource.upload_dab_config.id
      }

      volume_mounts {
        name = "dab-config"
        path = "/cfg"
      }

      command = [
        "dotnet",
        "Azure.DataApiBuilder.Service.dll",
        "--ConfigFileName",
        "/cfg/dab-config.json",
      ]
    }

    volume {
      name         = "dab-config"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.dab_config.name
    }
  }

  depends_on = [
    azurerm_container_app_environment_storage.dab_config,
    null_resource.upload_dab_config,
  ]
}
