# Azure Static Web App to host the Chase the Sun training dashboard.
# Free tier, westeurope (closest region to uksouth that SWA Free supports).
resource "azurerm_static_web_app" "dashboard" {
  name                = var.static_web_app_name
  resource_group_name = azurerm_resource_group.dab.name
  location            = "westeurope"
  sku_tier            = "Free"
  sku_size            = "Free"

  # Manage app settings declaratively so Terraform never removes them on a
  # plan that doesn't touch deploy_dashboard.
  app_settings = {
    DAB_ENDPOINT = "${local.dab_endpoint}/api"
  }
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

# Render the HTML template (substitute placeholders), deploy to the SWA via the
# SWA CLI, and apply the DAB_ENDPOINT app setting in a single step.
# Keeping deploy and appsettings in one resource avoids a destroy-phase cycle
# that arises when two null_resources depend on each other (the SWA CLI deploy
# resets managed function environment variables, so the setting must be applied
# after deploy — merging them guarantees that without any inter-resource edge).
resource "null_resource" "deploy_dashboard" {
  depends_on = [
    azurerm_static_web_app.dashboard,
    null_resource.dashboard_redirect_uris,
  ]

  triggers = {
    html_hash               = filemd5("${path.module}/dashboard/index.html")
    synclog_hash            = filemd5("${path.module}/dashboard/synclog.html")
    swa_name                = azurerm_static_web_app.dashboard.name
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'Stop'

      # Render template — substitute placeholders
      $content = Get-Content "${path.module}/dashboard/index.html" -Raw -Encoding UTF8
      $content = $content -replace '__APP_ID__',        '${azuread_application.dab_api.client_id}'
      $content = $content -replace '__TENANT_ID__',     '${local.tenant_id}'
      $content = $content -replace '__DAB_ENDPOINT__',  '${local.dab_endpoint}'

      # Write to a temp deploy folder
      $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) 'swa_dashboard'
      New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
      $content | Set-Content "$tmpDir/index.html" -Encoding UTF8

      # Render synclog page — substitute DAB endpoint placeholder
      $synclog = Get-Content "${path.module}/dashboard/synclog.html" -Raw -Encoding UTF8
      $synclog = $synclog -replace '__DAB_ENDPOINT__', '${local.dab_endpoint}'
      $synclog | Set-Content "$tmpDir/synclog.html" -Encoding UTF8

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
