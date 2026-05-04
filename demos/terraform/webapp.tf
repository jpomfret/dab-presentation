# Azure Static Web App to host the Chase the Sun training dashboard.
# Free tier, westeurope (closest region to uksouth that SWA Free supports).
resource "azurerm_static_web_app" "dashboard" {
  name                = var.static_web_app_name
  resource_group_name = azurerm_resource_group.dab.name
  location            = "westeurope"
  sku_tier            = "Free"
  sku_size            = "Free"
}

# Register the SWA URL (and localhost for local testing) as SPA redirect URIs
# on the Entra app registration so MSAL can complete the auth flow.
resource "null_resource" "dashboard_redirect_uris" {
  depends_on = [azurerm_static_web_app.dashboard]

  triggers = {
    swa_hostname = azurerm_static_web_app.dashboard.default_host_name
    app_id       = azuread_application.dab_api.client_id
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'Stop'
      az ad app update --id ${azuread_application.dab_api.client_id} `
        --spa-redirect-uris `
          "https://${azurerm_static_web_app.dashboard.default_host_name}" `
          "http://localhost:4280" `
          "http://localhost:3000"
      Write-Host "SPA redirect URIs registered for ${azurerm_static_web_app.dashboard.default_host_name}"
    EOT
  }
}

# Set the DAB_ENDPOINT app setting so the SWA API proxy functions can reach DAB.
# Must run AFTER deploy_dashboard — the SWA CLI deploy can reset managed function
# environment variables, so we apply settings last.
resource "null_resource" "swa_app_settings" {
  depends_on = [
    azurerm_static_web_app.dashboard,
    null_resource.deploy_dashboard,
  ]

  triggers = {
    swa_name     = azurerm_static_web_app.dashboard.name
    dab_endpoint = local.dab_endpoint
    deploy_id    = null_resource.deploy_dashboard.id
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'Stop'
      az staticwebapp appsettings set `
        --name "${azurerm_static_web_app.dashboard.name}" `
        --resource-group "${var.resource_group_name}" `
        --setting-names "DAB_ENDPOINT=${local.dab_endpoint}/api"
      Write-Host "SWA app setting DAB_ENDPOINT set."
    EOT
  }
}

# Render the HTML template (substitute placeholders) and deploy to the SWA
# using the SWA CLI. Re-runs whenever the dashboard HTML or API functions change.
resource "null_resource" "deploy_dashboard" {
  depends_on = [
    azurerm_static_web_app.dashboard,
    null_resource.dashboard_redirect_uris,
  ]

  triggers = {
    html_hash             = filemd5("${path.module}/dashboard/index.html")
    wellness_index_hash   = filemd5("${path.module}/dashboard/api/wellness/index.js")
    wellness_binding_hash = filemd5("${path.module}/dashboard/api/wellness/function.json")
    activities_index_hash = filemd5("${path.module}/dashboard/api/activities/index.js")
    activities_binding_hash = filemd5("${path.module}/dashboard/api/activities/function.json")
    swa_name              = azurerm_static_web_app.dashboard.name
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'Stop'

      # Render template — substitute placeholders
      $content = Get-Content "${path.module}/dashboard/index.html" -Raw
      $content = $content -replace '__APP_ID__',     '${azuread_application.dab_api.client_id}'
      $content = $content -replace '__TENANT_ID__',  '${local.tenant_id}'

      # Write to a temp deploy folder
      $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) 'swa_dashboard'
      New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
      $content | Set-Content "$tmpDir/index.html" -Encoding UTF8

      # Get SWA deployment token
      $deployToken = (az staticwebapp secrets list `
        --name "${azurerm_static_web_app.dashboard.name}" `
        --resource-group "${var.resource_group_name}" `
        --query "properties.apiKey" -o tsv)

      # Deploy via SWA CLI
      npx --yes @azure/static-web-apps-cli deploy $tmpDir `
        --api-location "${path.module}/dashboard/api" `
        --api-language node --api-version 18 `
        --deployment-token $deployToken `
        --env production

      Remove-Item $tmpDir -Recurse -Force
      Write-Host "Dashboard deployed to https://${azurerm_static_web_app.dashboard.default_host_name}"
    EOT
  }
}
