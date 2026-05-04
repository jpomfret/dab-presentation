resource "azurerm_service_plan" "dab" {
  name                = var.app_service_plan_name
  resource_group_name = azurerm_resource_group.dab.name
  location            = azurerm_resource_group.dab.location
  os_type             = "Windows"
  sku_name            = "Y1" # Consumption plan
}

resource "azurerm_windows_function_app" "dab" {
  name                       = var.function_app_name
  resource_group_name        = azurerm_resource_group.dab.name
  location                   = azurerm_resource_group.dab.location
  storage_account_name       = azurerm_storage_account.dab.name
  storage_account_access_key = azurerm_storage_account.dab.primary_access_key
  service_plan_id            = azurerm_service_plan.dab.id

  site_config {
    application_stack {
      powershell_core_version = "7.4"
    }
  }

  app_settings = {
    FUNCTIONS_EXTENSION_VERSION = "~4"
    # DAB container endpoint — the function calls this to proxy requests
    DAB_ENDPOINT   = local.dab_endpoint
    # App registration app ID — used to request tokens for the DAB API audience
    DAB_API_APP_ID = azuread_application.dab_api.client_id
    # AZURE_CLIENT_ID is set by a separate null_resource after the MI is created
    # because it references this resource's own computed identity.principal_id
  }

  identity {
    type = "SystemAssigned"
  }

  # Prevent Terraform from overwriting AZURE_CLIENT_ID that is set post-deploy
  lifecycle {
    ignore_changes = [app_settings["AZURE_CLIENT_ID"]]
  }
}

# AZURE_CLIENT_ID can't be set in the resource above because it references
# the function's own identity.principal_id (a self-referential cycle).
# This null_resource sets it after the function app and its MI are created.
resource "null_resource" "function_client_id_setting" {
  depends_on = [azurerm_windows_function_app.dab]

  triggers = {
    principal_id = azurerm_windows_function_app.dab.identity[0].principal_id
  }

  provisioner "local-exec" {
    command = "az functionapp config appsettings set --name ${var.function_app_name} --resource-group ${var.resource_group_name} --settings AZURE_CLIENT_ID=${azurerm_windows_function_app.dab.identity[0].principal_id}"
  }
}
