resource "azurerm_application_insights" "dab" {
  name                = var.app_insights_name
  resource_group_name = azurerm_resource_group.dab.name
  location            = azurerm_resource_group.dab.location
  application_type    = "web"
}

resource "azurerm_service_plan" "dab" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.dab.name
  location            = azurerm_resource_group.dab.location
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption plan

  # os_type is immutable, so switching Windows → Linux forces a replacement.
  # Default Terraform behaviour is create-then-destroy, which needs 2 quota
  # slots simultaneously. Destroy-first keeps us within the single-slot limit.
  lifecycle {
    create_before_destroy = false
  }
}

resource "azurerm_linux_function_app" "dab" {
  name                       = var.function_app_name
  resource_group_name        = azurerm_resource_group.dab.name
  location                   = azurerm_resource_group.dab.location
  storage_account_name       = azurerm_storage_account.dab.name
  storage_account_access_key = azurerm_storage_account.dab.primary_access_key
  service_plan_id            = azurerm_service_plan.dab.id

  site_config {
    application_insights_key               = azurerm_application_insights.dab.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.dab.connection_string

    application_stack {
      powershell_core_version = "7.4"
    }
  }

  app_settings = {
    FUNCTIONS_EXTENSION_VERSION = "~4"
    # DAB container endpoint — HTTP so Invoke-RestMethod uses plain HTTP/1.1.
    # Container Apps HTTPS uses TLS ALPN which causes SocketsHttpHandler to
    # negotiate HTTP/2; the ingress returns InvalidOperationException on that path.
    # allow_insecure_connections = true on the Container App enables this HTTP URL.
    DAB_ENDPOINT   = local.dab_endpoint_http
    # App registration app ID — used to request tokens for the DAB API audience
    DAB_API_APP_ID = azuread_application.dab_api.client_id
    # AZURE_CLIENT_ID is set by a separate null_resource after the MI is created
    # because it references this resource's own computed identity.principal_id

    # Intervals.icu sync settings
    INTERVALS_ATHLETE_ID = var.intervals_athlete_id
    INTERVALS_API_KEY    = var.intervals_api_key

    # Run-from-package: SAS URL pointing at the zipped function code in blob storage.
    # Terraform manages this end-to-end — no null_resource or local-exec needed.
    WEBSITE_RUN_FROM_PACKAGE = "${azurerm_storage_blob.function_package.url}${data.azurerm_storage_account_sas.function_package.sas}"
    # Changes when the zip content changes, triggering a function app restart to pick up new code.
    FUNCTION_PACKAGE_VERSION = data.archive_file.function_package.output_md5
  }

  identity {
    type = "SystemAssigned"
  }

  # AZURE_CLIENT_ID is set by null_resource.function_client_id_setting (self-referential
  # cycle — can't reference this resource's own identity.principal_id in app_settings).
  lifecycle {
    ignore_changes = [
      app_settings["AZURE_CLIENT_ID"],
    ]
  }
}

# AZURE_CLIENT_ID can't be set in the resource above because it references
# the function's own identity.principal_id (a self-referential cycle).
# This null_resource sets it after the function app and its MI are created.
resource "null_resource" "function_client_id_setting" {
  depends_on = [azurerm_linux_function_app.dab]

  triggers = {
    principal_id = azurerm_linux_function_app.dab.identity[0].principal_id
  }

  provisioner "local-exec" {
    command = "az functionapp config appsettings set --name ${var.function_app_name} --resource-group ${var.resource_group_name} --settings AZURE_CLIENT_ID=${azurerm_linux_function_app.dab.identity[0].principal_id}"
  }
}

# Zip the function code. Re-runs whenever any file under functions/ changes.
data "archive_file" "function_package" {
  type        = "zip"
  source_dir  = "${path.module}/functions"
  output_path = "${path.module}/functions_package.zip"
}

# Upload the zip to blob storage. Terraform re-uploads whenever content_md5 changes.
resource "azurerm_storage_blob" "function_package" {
  name                   = "intervalssync.zip"
  storage_account_name   = azurerm_storage_account.dab.name
  storage_container_name = azurerm_storage_container.function_packages.name
  type                   = "Block"
  source                 = data.archive_file.function_package.output_path
  content_md5            = data.archive_file.function_package.output_md5
}

# Account-level read SAS — used to build WEBSITE_RUN_FROM_PACKAGE.
# Valid until 2099; the Functions runtime fetches the zip on cold start.
data "azurerm_storage_account_sas" "function_package" {
  connection_string = azurerm_storage_account.dab.primary_connection_string
  https_only        = true

  resource_types {
    service   = false
    container = false
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  start  = "2025-01-01T00:00:00Z"
  expiry = "2099-01-01T00:00:00Z"

  permissions {
    read    = true
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
    tag     = false
    filter  = false
  }
}
