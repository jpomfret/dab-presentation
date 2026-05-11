<#
app_insights_connection_string = <sensitive>
app_registration_client_id = "2e270072-8631-44fd-95cd-490e72ae04a3"
app_registration_identifier_uri = "api://2e270072-8631-44fd-95cd-490e72ae04a3"
container_identity_principal_id = "967e7bc2-e6bf-4b89-8f0b-72fb9ab62968"
dab_api_endpoint = "https://ca-dab-prod-001.greenbush-ad7ca4de.uksouth.azurecontainerapps.io/api"
dab_swagger_url = "https://ca-dab-prod-001.greenbush-ad7ca4de.uksouth.azurecontainerapps.io/swagger"
dashboard_url = "https://blue-mud-0e8339c03.7.azurestaticapps.net"
function_app_hostname = "func-dab-prod-001.azurewebsites.net"
function_app_identity_principal_id = "fe045b76-1754-4223-bb9f-013eaf598fb2"
get_user_token_command = "az account get-access-token --resource 'api://2e270072-8631-44fd-95cd-490e72ae04a3' | ConvertFrom-Json | Select-Object -ExpandProperty accessToken"
resource_group_name = "rg-dab-prod-001"
sql_server_fqdn = "sqlsvr-dab-prod-001.database.windows.net"
storage_account_name = "dabconfigstorage001"
tenant_id = "f98042ad-9bbc-499d-adb4-17193696b9a3"

#>

$data = Invoke-RestMethod -Uri 'https://ca-dab-prod-001.greenbush-ad7ca4de.uksouth.azurecontainerapps.io/api/dbo_BuildVersion'
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
$appID = '2e270072-8631-44fd-95cd-490e72ae04a3'
$tenantId = 'f98042ad-9bbc-499d-adb4-17193696b9a3'
az login --tenant $tenantId --scope "api://$appID/.default"

$token = (az account get-access-token --tenant $tenantId --resource "api://$appID" | ConvertFrom-Json).accessToken

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
Invoke-RestMethod -Uri 'https://ca-dab-prod-001.greenbush-ad7ca4de.uksouth.azurecontainerapps.io/api/dbo_BuildVersion' -Headers $headers



$masterKey = (az functionapp keys list `
  --resource-group rg-dab-prod-001 `
  --name func-dab-prod-001 `
  --query masterKey -o tsv)

Invoke-RestMethod `
  -Uri     'https://func-dab-prod-001.azurewebsites.net/admin/functions/IntervalsSync' `
  -Method  Post `
  -Headers @{ 'x-functions-key' = $masterKey } `
  -ContentType 'application/json' `
  -Body    '{}'

# check for data in the database
$token = (az account get-access-token --resource https://database.windows.net | ConvertFrom-Json).accessToken
Invoke-Sqlcmd `
  -ServerInstance (terraform output -raw sql_server_fqdn) `
  -Database       sqldb-dab-prod-001 `
  -AccessToken    $token `
  -Query          "SELECT TOP 10 * FROM dbo.IntervalsWellness ORDER BY RecordDate DESC"

# get data from database with dab
$token = (az account get-access-token --resource "api://$appID" | ConvertFrom-Json).accessToken
Invoke-RestMethod `
  -Uri 'http://ci-dab-prod-001.uksouth.azurecontainer.io:5000/api/dbo_IntervalsWellness/Recent' `
  -Headers @{ 'Authorization' = "Bearer $token" }


Invoke-RestMethod 'http://ci-dab-prod-001.uksouth.azurecontainer.io:5000/api/IntervalsWellness' -Headers $headers
Invoke-RestMethod 'http://ci-dab-prod-001.uksouth.azurecontainer.io:5000/api/IntervalsActivity' -Headers $headers
