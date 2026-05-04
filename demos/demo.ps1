<#

app_registration_client_id = "4f4585ac-8558-4cee-86a9-75733d991305"
app_registration_identifier_uri = "api://4f4585ac-8558-4cee-86a9-75733d991305"
container_identity_principal_id = "c0e5dff3-db3c-47bd-a395-666437cd90c1"
dab_api_endpoint = "http://ci-dab-prod-001.uksouth.azurecontainer.io:5000/api"
dab_swagger_url = "http://ci-dab-prod-001.uksouth.azurecontainer.io:5000/swagger"
function_app_hostname = "func-dab-prod-001.azurewebsites.net"
function_app_identity_principal_id = "692713d8-c4e1-42bf-bd8e-ea135b24ec5e"
get_user_token_command = "az account get-access-token --resource 'api://4f4585ac-8558-4cee-86a9-75733d991305' | ConvertFrom-Json | Select-Object -ExpandProperty accessToken"
resource_group_name = "rg-dab-prod-001"
sql_server_fqdn = "sqlsvr-dab-prod-001.database.windows.net"
storage_account_name = "dabconfigstorage001"
tenant_id = "f98042ad-9bbc-499d-adb4-17193696b9a3"

#>

$data = Invoke-RestMethod -Uri 'http://ci-dab-prod-001.uksouth.azurecontainer.io:5000/api/dbo_BuildVersion'
$data.value

# Invoke-RestMethod:                                                                                                      
# {
#   "error": {
#     "code": "AuthorizationCheckFailed",
#     "message": "Authorization Failure: Access Not Allowed.",
#     "status": 403
#   }
# }

## auth
$appID = '7f5ca04f-813d-44ea-8d45-4e09db07696c'
$tenantId = 'f98042ad-9bbc-499d-adb4-17193696b9a3'
az login --tenant $tenantId --scope "api://$appID/.default"

$token = (az account get-access-token --resource "api://$appId" | ConvertFrom-Json).accessToken

# Verify it's v1.0
$tokenParts = $token.Split('.')
$payload = $tokenParts[1]
while ($payload.Length % 4 -ne 0) { $payload += '=' }
$decodedBytes = [System.Convert]::FromBase64String($payload)
$decodedJson = [System.Text.Encoding]::UTF8.GetString($decodedBytes)
$tokenClaims = $decodedJson | ConvertFrom-Json

Write-Host "Issuer: $($tokenClaims.iss)"  # Should be https://sts.windows.net/tenant-id/

# Test the API
$headers = @{ 'Authorization' = "Bearer $token" }
Invoke-RestMethod -Uri 'http://ci-dab-prod-001.uksouth.azurecontainer.io:5000/api/dbo_BuildVersion' -Headers $headers
