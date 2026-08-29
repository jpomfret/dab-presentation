<#
.SYNOPSIS
    One-off backfill of intervals.icu wellness + activity history into Azure SQL
    via the DAB stored-procedure REST endpoints.

.DESCRIPTION
    The IntervalsSync Azure Function only ever pulls a rolling 7-day window — it was
    built to keep the database fresh in the run-up to the ride. Now that Chase the Sun
    (20 June 2026) is in the past, the demos want the *whole training block* on show:
    January through the ride itself.

    This script does exactly what the Function does — fetch from intervals.icu, upsert
    through DAB's UpsertWellness / UpsertActivity endpoints — but over an arbitrary date
    range, run locally with a user token instead of the Function's managed identity.

    Everything still goes THROUGH DAB. No direct SQL. Same story spine as the talk.

.PARAMETER Oldest
    Start of the range (inclusive), yyyy-MM-dd. Default 2026-01-01.

.PARAMETER Newest
    End of the range (inclusive), yyyy-MM-dd. Default 2026-06-20 (race day).

.PARAMETER IntervalsApiKey
    intervals.icu API key (Settings → Developer). Falls back to $env:INTERVALS_API_KEY.

.PARAMETER IntervalsAthleteId
    intervals.icu athlete id. "0" means "me". Default "0".

.PARAMETER DabEndpoint
    Base URL of the DAB container (no trailing /api). Defaults to the prod container.

.PARAMETER AppId
    Client id of the DAB-API-Access app registration (token audience api://<AppId>).

.EXAMPLE
    $env:INTERVALS_API_KEY = '<your-key>'
    az login
    ./backfill-intervals.ps1

.EXAMPLE
    ./backfill-intervals.ps1 -Oldest 2026-01-01 -Newest 2026-06-20 -IntervalsApiKey '<key>'
#>
[CmdletBinding()]
param(
    [string] $Oldest             = '2026-01-01',
    [string] $Newest             = '2026-06-20',
    [string] $IntervalsApiKey    = $env:INTERVALS_API_KEY,
    [string] $IntervalsAthleteId = '0',
    [string] $DabEndpoint        = 'https://ca-dab-prod-001.greenbush-ad7ca4de.uksouth.azurecontainerapps.io',
    [string] $AppId              = '2e270072-8631-44fd-95cd-490e72ae04a3'
)

$ErrorActionPreference = 'Stop'

if (-not $IntervalsApiKey) {
    throw 'No intervals.icu API key. Pass -IntervalsApiKey or set $env:INTERVALS_API_KEY.'
}

$dabBase = $DabEndpoint.TrimEnd('/')

Write-Host "Backfilling intervals.icu -> DAB" -ForegroundColor Cyan
Write-Host "  Range   : $Oldest .. $Newest"
Write-Host "  Athlete : $IntervalsAthleteId"
Write-Host "  DAB     : $dabBase"
Write-Host ""

$startTime = Get-Date

# ── intervals.icu auth (basic; username is the literal "API_KEY") ────────────────
$base64Creds      = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("API_KEY:$IntervalsApiKey"))
$intervalsHeaders = @{ Authorization = "Basic $base64Creds" }

# ── DAB auth (user token via az; the Azure CLI is pre-authorized on the app reg) ─
Write-Host "Acquiring DAB token (api://$AppId) ..."
$token = (az account get-access-token --resource "api://$AppId" | ConvertFrom-Json).accessToken
if (-not $token) { throw 'Failed to get a token. Run "az login" first (an account pre-authorized on the app registration).' }
$dabHeaders = @{ Authorization = "Bearer $token" }

# ── Tracking counters ────────────────────────────────────────────────────────────
$wellnessFetched    = 0
$wellnessUpserted   = 0
$activitiesFetched  = 0
$activitiesUpserted = 0
$syncStatus         = 'Success'
$syncError          = $null

try {
    # ── Fetch the FULL range in one call — intervals.icu supports oldest/newest ──
    $wellnessUrl = "https://intervals.icu/api/v1/athlete/$IntervalsAthleteId/wellness?oldest=$Oldest&newest=$Newest"
    $wellness    = Invoke-RestMethod -Uri $wellnessUrl -Headers $intervalsHeaders -Method Get
    $wellnessFetched = $wellness.Count
    Write-Host "Fetched $wellnessFetched wellness records" -ForegroundColor Green

    $activitiesUrl = "https://intervals.icu/api/v1/athlete/$IntervalsAthleteId/activities?oldest=$Oldest&newest=$Newest"
    $activities    = Invoke-RestMethod -Uri $activitiesUrl -Headers $intervalsHeaders -Method Get
    $activitiesFetched = $activities.Count
    Write-Host "Fetched $activitiesFetched activity records" -ForegroundColor Green
    Write-Host ""

    # ── Upsert wellness via DAB ──────────────────────────────────────────────────
    foreach ($record in $wellness) {
        $body = @{
            RecordDate   = $record.id
            CTL          = $record.ctl
            ATL          = $record.atl
            RampRate     = $record.rampRate
            CTLLoad      = $record.ctlLoad
            ATLLoad      = $record.atlLoad
            Weight       = $record.weight
            RestingHR    = $record.restingHR
            HRV          = $record.hrv
            SleepSecs    = $record.sleepSecs
            SleepScore   = $record.sleepScore
            SleepQuality = $record.sleepQuality
            Form         = $record.form
            Updated      = $record.updated
        } | ConvertTo-Json -Compress

        # Byte-array body avoids the PS 7.4 StringContent/Content-Type conflict.
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
        Invoke-RestMethod -Uri "$dabBase/api/UpsertWellness" -Method Post -Headers $dabHeaders -ContentType 'application/json' -Body $bodyBytes | Out-Null
        $wellnessUpserted++
        if ($wellnessUpserted % 25 -eq 0) { Write-Host "  ...$wellnessUpserted wellness upserted" }
    }
    Write-Host "Upserted $wellnessUpserted wellness records" -ForegroundColor Green

    # ── Upsert activities via DAB ────────────────────────────────────────────────
    foreach ($activity in $activities) {
        # Activities feed can return wellness-only rows with no id — skip them.
        if (-not $activity.id) { continue }

        $body = @{
            ActivityId          = $activity.id
            StartDateLocal      = $activity.start_date_local
            ActivityType        = $activity.type
            ActivityName        = $activity.name
            MovingTime          = $activity.moving_time
            Distance            = $activity.distance
            TrainingLoad        = $activity.icu_training_load
            ATLLoad             = $activity.icu_atl_load
            CTLLoad             = $activity.icu_ctl_load
            Intensity           = $activity.icu_intensity
            AverageWatts        = $activity.average_watts
            AverageHeartrate    = $activity.average_heartrate
            TotalElevationGain  = $activity.total_elevation_gain
            CTL                 = $activity.icu_ctl
            ATL                 = $activity.icu_atl
        } | ConvertTo-Json -Compress

        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
        Invoke-RestMethod -Uri "$dabBase/api/UpsertActivity" -Method Post -Headers $dabHeaders -ContentType 'application/json' -Body $bodyBytes | Out-Null
        $activitiesUpserted++
        if ($activitiesUpserted % 25 -eq 0) { Write-Host "  ...$activitiesUpserted activities upserted" }
    }
    Write-Host "Upserted $activitiesUpserted activity records" -ForegroundColor Green

} catch {
    $syncStatus = 'Error'
    $syncError  = $_.Exception.Message
    Write-Host "Backfill ERROR [$($_.Exception.GetType().FullName)]: $syncError" -ForegroundColor Red
    Write-Host "  At: $($_.InvocationInfo.PositionMessage)"
}

# ── Write a sync-log row via DAB so the backfill shows up on the Sync Log page ──
try {
    $durationMs = [int]((Get-Date) - $startTime).TotalMilliseconds
    $logBody = @{
        Source             = 'IntervalsBackfill'
        TriggerType        = 'Backfill'
        DateRangeStart     = $Oldest
        DateRangeEnd       = $Newest
        WellnessFetched    = $wellnessFetched
        WellnessUpserted   = $wellnessUpserted
        ActivitiesFetched  = $activitiesFetched
        ActivitiesUpserted = $activitiesUpserted
        DurationMs         = $durationMs
        Status             = $syncStatus
        ErrorMessage       = $syncError
    } | ConvertTo-Json -Compress

    $logBodyBytes = [System.Text.Encoding]::UTF8.GetBytes($logBody)
    Invoke-RestMethod -Uri "$dabBase/api/LogSync" -Method Post -Headers $dabHeaders -ContentType 'application/json' -Body $logBodyBytes | Out-Null
    Write-Host ""
    Write-Host "Sync log written: $syncStatus, ${durationMs}ms" -ForegroundColor Cyan
} catch {
    Write-Host "WARNING: Failed to write sync log: $($_.Exception.Message)" -ForegroundColor Yellow
}

if ($syncStatus -eq 'Error') { throw "Backfill failed: $syncError" }

Write-Host ""
Write-Host "Backfill complete." -ForegroundColor Green
