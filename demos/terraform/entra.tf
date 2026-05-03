resource "random_uuid" "app_role_id" {}
resource "random_uuid" "user_impersonation_scope_id" {}

resource "azuread_application" "dab_api" {
  display_name     = "DAB-API-Access"
  sign_in_audience = "AzureADMyOrg"

  api {
    # Must be version 1 — the Azure CLI user-auth flow and the function both
    # need v1 tokens; issuer will be https://sts.windows.net/<tenant-id>/
    requested_access_token_version = 1

    # Delegated scope for interactive user authentication via Azure CLI
    oauth2_permission_scope {
      id                         = random_uuid.user_impersonation_scope_id.result
      value                      = "user_impersonation"
      type                       = "User"
      enabled                    = true
      admin_consent_display_name = "Access DAB API as user"
      admin_consent_description  = "Allow the application to access DAB API on behalf of the signed-in user"
      user_consent_display_name  = "Access DAB API as you"
      user_consent_description   = "Allow the application to access DAB API on your behalf"
    }
  }

  # App role for service-to-service (application) tokens
  # The Function App's managed identity is assigned this role below.
  app_role {
    id                   = random_uuid.app_role_id.result
    value                = "DAB.Access"
    display_name         = "DAB.Access"
    description          = "Allow access to DAB API"
    allowed_member_types = ["Application"]
    enabled              = true
  }
}

# Pre-authorize the Azure CLI so users can request tokens without a consent UI.
# The CLI app ID is a well-known Microsoft constant.
resource "azuread_application_pre_authorized" "azure_cli" {
  application_id       = azuread_application.dab_api.id
  authorized_client_id = "04b07795-8ddb-461a-bbee-02f9e1bf7b46" # Microsoft Azure CLI
  permission_ids       = [random_uuid.user_impersonation_scope_id.result]
}

# identifier_uris must reference the app's own client_id, which is only known
# after creation, so we set it via az CLI after the app is created.
resource "null_resource" "app_identifier_uri" {
  depends_on = [azuread_application.dab_api]

  triggers = {
    app_id = azuread_application.dab_api.client_id
  }

  provisioner "local-exec" {
    command = "az ad app update --id ${azuread_application.dab_api.client_id} --identifier-uris api://${azuread_application.dab_api.client_id}"
  }
}

# Enterprise Application (service principal) for the App Registration
resource "azuread_service_principal" "dab_api" {
  client_id = azuread_application.dab_api.client_id
}

# Assign the DAB.Access app role to the Function App's managed identity.
# This is the service-to-service grant that lets the function get a token
# with the DAB.Access role claim and call the DAB API as an application.
resource "azuread_app_role_assignment" "function_dab_access" {
  app_role_id         = random_uuid.app_role_id.result
  principal_object_id = azurerm_windows_function_app.dab.identity[0].principal_id
  resource_object_id  = azuread_service_principal.dab_api.object_id
}
