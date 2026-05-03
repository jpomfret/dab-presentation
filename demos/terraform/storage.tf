resource "azurerm_storage_account" "dab" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.dab.name
  location                 = azurerm_resource_group.dab.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # Shared key access is required so the container instance can mount the
  # file share using the storage account key.
  shared_access_key_enabled = true
}

resource "azurerm_storage_share" "dab" {
  name               = var.file_share_name
  storage_account_id = azurerm_storage_account.dab.id
  quota              = 1
}

# Render the dab-config.json from a template (substitutes tenant ID and app ID)
# and upload it to the file share so the container can mount and read it.
resource "null_resource" "upload_dab_config" {
  depends_on = [
    azurerm_storage_share.dab,
    azuread_application.dab_api,
    null_resource.app_identifier_uri,
  ]

  triggers = {
    app_id    = azuread_application.dab_api.client_id
    tenant_id = local.tenant_id
    share_id  = azurerm_storage_share.dab.id
  }

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'Stop'
      $config = Get-Content "${path.module}/templates/dab-config.json.tpl" -Raw
      $config = $config `
        -replace '__APP_ID__',    '${azuread_application.dab_api.client_id}' `
        -replace '__TENANT_ID__', '${local.tenant_id}'
      $tmpFile = [System.IO.Path]::GetTempFileName() + '.json'
      $config | Set-Content $tmpFile -Encoding UTF8
      az storage file upload `
        --account-name "${var.storage_account_name}" `
        --account-key  "${azurerm_storage_account.dab.primary_access_key}" `
        --share-name   "${var.file_share_name}" `
        --source       $tmpFile `
        --path         "dab-config.json" `
        --overwrite
      Remove-Item $tmpFile
      Write-Host "dab-config.json uploaded to file share."
    EOT
  }
}
