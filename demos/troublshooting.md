

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