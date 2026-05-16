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

# anon GET access
Invoke-RestMethod -Uri 'https://ca-dab-prod-001.greenbush-ad7ca4de.uksouth.azurecontainerapps.io/api/IntervalsWellness'
Invoke-RestMethod -Uri 'https://ca-dab-prod-001.greenbush-ad7ca4de.uksouth.azurecontainerapps.io/api/IntervalsActivity'

# but POST requires a token
$body = @{
    "RecordDate" = (Get-Date).ToString("o")
    "Steps" = 1234
    "HeartRate" = 80
} | ConvertTo-Json

$iwr = @{
    Uri = 'https://ca-dab-prod-001.greenbush-ad7ca4de.uksouth.azurecontainerapps.io/api/IntervalsWellness'
    Method = 'Post'
    Body = $body
    ContentType = "application/json"
    # Headers = @{ 'Authorization' = "Bearer $token" }
}
Invoke-RestMethod @iwr


# run the function and review the logs
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


