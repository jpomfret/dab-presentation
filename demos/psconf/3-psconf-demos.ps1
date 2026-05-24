<#
    PSConfEU 2026 — Persist Your PowerShell Script Data with Data API Builder
    Demo: calling a DAB REST API from PowerShell

    Infra values (from terraform output):
    dab_api_endpoint  = https://ca-dab-prod-001.greenbush-ad7ca4de.uksouth.azurecontainerapps.io/api
    app_registration_client_id     = 2e270072-8631-44fd-95cd-490e72ae04a3
    app_registration_identifier_uri = api://2e270072-8631-44fd-95cd-490e72ae4a3
#>

$baseUrl = 'https://ca-dab-prod-001.greenbush-ad7ca4de.uksouth.azurecontainerapps.io/api'
$appId   = '2e270072-8631-44fd-95cd-490e72ae04a3'

#region 1 — No auth → 403

# DAB is running in production mode with Entra ID auth.
# Every entity that requires the Authenticated role will reject an anonymous call.

Invoke-RestMethod -Uri "$baseUrl/dbo_BuildVersion"

# {
#   "error": {
#     "code": "AuthorizationCheckFailed",
#     "message": "Authorization Failure: Access Not Allowed.",
#     "status": 403
#   }
# }

#endregion


#region 2 — Get a token, call again → data

# Log in and request a token scoped to our DAB app registration.
$tenantId = 'f98042ad-9bbc-499d-adb4-17193696b9a3'
az login --tenant $tenantId --scope "api://$appID/.default"

$token = az account get-access-token --resource "api://$appId" |
    ConvertFrom-Json |
    Select-Object -ExpandProperty accessToken

$headers = @{ Authorization = "Bearer $token" }

# Same endpoint — now we get data back.
$result = Invoke-RestMethod -Uri "$baseUrl/dbo_BuildVersion" -Headers $headers
$result.value

#endregion


#region 3 — SyncLog: paging, filtering, and selecting fields

# Every time the Azure Function runs it writes a row to dbo.SyncLog.
# DAB exposes it as the SyncLog entity so we can query it straight from PowerShell.

# --- 3a. First page — 5 most recent runs ---
$response = Invoke-RestMethod -Uri "$baseUrl/SyncLog?`$orderby=RunAt desc&`$first=5" -Headers $headers
$response.value | Format-Table

# --- 3b. Next page — follow the nextLink DAB gives you ---
# DAB returns a nextLink when there are more rows. Use it as-is.
$response | Format-List

if ($response.nextLink) {
    $page2 = Invoke-RestMethod -Uri $response.nextLink -Headers $headers
    $page2.value | Format-Table
}

# --- 3c. Filter — only show Error runs ---
Invoke-RestMethod -Uri "$baseUrl/SyncLog?`$filter=Status eq 'Error'" -Headers $headers |
    Select-Object -ExpandProperty value | Format-Table

# --- 3d. Filter — runs from a specific source in the last 7 days ---
$since = (Get-Date).AddDays(-7).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
Invoke-RestMethod -Uri "$baseUrl/SyncLog?`$filter=Source eq 'IntervalsSync' and RunAt ge $since" -Headers $headers |
    Select-Object -ExpandProperty value | Format-Table

# --- 3e. Select — only the columns you actually need ---
Invoke-RestMethod -Uri "$baseUrl/SyncLog?`$select=LogId,RunAt,Source,Status,DurationMs&`$orderby=RunAt desc&`$first=10" -Headers $headers |
    Select-Object -ExpandProperty value | Format-Table

# --- 3f. Combine the lot — filter + select + order + page ---
Invoke-RestMethod -Uri "$baseUrl/SyncLog?`$filter=Status eq 'Success'&`$select=LogId,RunAt,TriggerType,WellnessUpserted,ActivitiesUpserted&`$orderby=RunAt desc&`$first=5" -Headers $headers |
    Select-Object -ExpandProperty value

#endregion
