

```powershell
az container show --name ci-dab-prod-001 --resource-group rg-dab-prod-001 --query "{state:instanceView.state, events:containers[0].instanceView.events[-3:]}" -o json
```

```text
{
  "events": [
    {
      "count": 1,
      "firstTimestamp": "2026-05-03T09:42:25+00:00",
      "lastTimestamp": "2026-05-03T09:42:25+00:00",
      "message": "Successfully pulled image \"mcr.microsoft.com/azure-databases/data-api-builder@sha256:c33f48e502cf2e2470102e20a77f0e42ba1b1a43cfdee9f357fcbcab71702196\"",
      "name": "Pulled",
      "type": "Normal"
    },
    {
      "count": 3,
      "firstTimestamp": "2026-05-03T09:42:41+00:00",
      "lastTimestamp": "2026-05-03T10:17:10+00:00",
      "message": "Started container",
      "name": "Started",
      "type": "Normal"
    },
    {
      "count": 3,
      "firstTimestamp": "2026-05-03T10:17:08+00:00",
      "lastTimestamp": "2026-05-03T10:17:08+00:00",
      "message": "Killing container dab (platform initiated).",
      "name": "Killing",
      "type": "Normal"
    }
  ],
  "state": "Running"
}
```

---

## `AADSTS500011` — resource principal not found when requesting a token

**Symptom**

```
ERROR: AADSTS500011: The resource principal named api://<client-id> was not found in the tenant named <tenant>.
```

**Cause**

The `identifier_uris` field on the Entra App Registration was never set. Without it, Entra cannot locate the app as a token audience. The Terraform `null_resource.app_identifier_uri` provisioner may have failed silently on first apply (e.g. if the az CLI was authenticated to the wrong tenant at apply time).

**Fix**

```powershell
az ad app update --id <client-id> --identifier-uris "api://<client-id>"

# Verify
az ad app show --id <client-id> --query identifierUris
```

Then re-request the token — no app restart needed.

**Prevention**

The `null_resource.app_identifier_uri` provisioner now verifies the URI was actually set and throws if not, so a future failed apply will surface the error rather than silently continuing.

## Snippets

```PowerShell
az containerapp logs show `                                             pwsh   85  14:49:26 
  --name ca-dab-prod-001 `
  --resource-group rg-dab-prod-001 `
  --follow
```
