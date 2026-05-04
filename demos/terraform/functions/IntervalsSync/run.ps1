# IntervalsSync — Timer trigger (runs at 06:00 and 18:00 UTC daily)
#
# Fetches wellness and activity data from the intervals.icu API and upserts
# it into Azure SQL via the DAB stored-procedure REST endpoints, using the
# function app's managed identity (which holds the DAB.Access app role).
# Writes a summary row to dbo.SyncLog via the DAB LogSync endpoint on every run.
#
# Required app settings:
#   INTERVALS_ATHLETE_ID  — intervals.icu athlete ID (use "0" for yourself)
#   INTERVALS_API_KEY     — API key from intervals.icu /settings
#   DAB_ENDPOINT          — Base URL of the DAB container (e.g. http://host:5000)
#   DAB_API_APP_ID        — Client ID of the DAB-API-Access app registration

param($Timer)

$ErrorActionPreference = 'Stop'

# ── Configuration ──────────────────────────────────────────────────────────────
$athleteId = $env:INTERVALS_ATHLETE_ID
$apiKey    = $env:INTERVALS_API_KEY
$dabBase   = $env:DAB_ENDPOINT
$dabAppId  = $env:DAB_API_APP_ID

if (-not $athleteId -or -not $apiKey -or -not $dabBase -or -not $dabAppId) {
    throw 'Missing required app settings: INTERVALS_ATHLETE_ID, INTERVALS_API_KEY, DAB_ENDPOINT, DAB_API_APP_ID'
}

$startTime = Get-Date

# ── Basic auth header for intervals.icu (username is the literal "API_KEY") ───
$base64Creds    = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("API_KEY:$apiKey"))
$intervalsHeaders = @{ Authorization = "Basic $base64Creds" }

# ── Date range: last 7 days catches delayed wellness updates ───────────────────
$today   = Get-Date -Format 'yyyy-MM-dd'
$weekAgo = (Get-Date).AddDays(-7).ToString('yyyy-MM-dd')

Write-Host "IntervalsSync: fetching data from $weekAgo to $today"

# ── Tracking counters ──────────────────────────────────────────────────────────
$wellnessFetched    = 0
$wellnessUpserted   = 0
$activitiesFetched  = 0
$activitiesUpserted = 0
$syncStatus         = 'Success'
$syncError          = $null

try {
    # ── Fetch wellness records ─────────────────────────────────────────────────
    $wellnessUrl = "https://intervals.icu/api/v1/athlete/$athleteId/wellness?oldest=$weekAgo&newest=$today"
    $wellness    = Invoke-RestMethod -Uri $wellnessUrl -Headers $intervalsHeaders -Method Get
    $wellnessFetched = $wellness.Count
    Write-Host "Fetched $wellnessFetched wellness records"

    # ── Fetch activity records ─────────────────────────────────────────────────
    $activitiesUrl = "https://intervals.icu/api/v1/athlete/$athleteId/activities?oldest=$weekAgo&newest=$today"
    $activities    = Invoke-RestMethod -Uri $activitiesUrl -Headers $intervalsHeaders -Method Get
    $activitiesFetched = $activities.Count
    Write-Host "Fetched $activitiesFetched activity records"

    # ── Acquire DAB API token via managed identity ─────────────────────────────
    # Windows Consumption plan blocks direct IMDS (169.254.169.254). Use the
    # IDENTITY_ENDPOINT / IDENTITY_HEADER env vars injected by the Functions host.
    $tokenUri  = "$($env:IDENTITY_ENDPOINT)?api-version=2019-08-01&resource=api://$dabAppId"
    $tokenResp = Invoke-RestMethod -Uri $tokenUri -Headers @{ 'X-IDENTITY-HEADER' = $env:IDENTITY_HEADER }
    $dabHeaders = @{
        Authorization  = "Bearer $($tokenResp.access_token)"
        'Content-Type' = 'application/json'
    }

    # ── Upsert wellness records via DAB ───────────────────────────────────────
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

        Invoke-RestMethod -Uri "$dabBase/api/UpsertWellness" -Method Post -Headers $dabHeaders -Body $body
        $wellnessUpserted++
    }
    Write-Host "Upserted $wellnessUpserted wellness records"

    # ── Upsert activity records via DAB ───────────────────────────────────────
    foreach ($activity in $activities) {
        # Activities endpoint can return wellness-only rows with no id — skip them
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

        Invoke-RestMethod -Uri "$dabBase/api/UpsertActivity" -Method Post -Headers $dabHeaders -Body $body
        $activitiesUpserted++
    }
    Write-Host "Upserted $activitiesUpserted activity records"

} catch {
    $syncStatus = 'Error'
    $syncError  = $_.Exception.Message
    Write-Host "IntervalsSync ERROR: $syncError"
}

# ── Write sync log via DAB ─────────────────────────────────────────────────────
# Runs whether the sync succeeded or failed so we always have a record.
try {
    $durationMs = [int]((Get-Date) - $startTime).TotalMilliseconds

    # Token may not have been acquired yet if the error was early — acquire now
    if (-not $dabHeaders) {
        $tokenUri  = "$($env:IDENTITY_ENDPOINT)?api-version=2019-08-01&resource=api://$dabAppId"
        $tokenResp = Invoke-RestMethod -Uri $tokenUri -Headers @{ 'X-IDENTITY-HEADER' = $env:IDENTITY_HEADER }
        $dabHeaders = @{
            Authorization  = "Bearer $($tokenResp.access_token)"
            'Content-Type' = 'application/json'
        }
    }

    $triggerType = if ($Timer.IsPastDue) { 'Manual' } else { 'Timer' }

    $logBody = @{
        TriggerType        = $triggerType
        DateRangeStart     = $weekAgo
        DateRangeEnd       = $today
        WellnessFetched    = $wellnessFetched
        WellnessUpserted   = $wellnessUpserted
        ActivitiesFetched  = $activitiesFetched
        ActivitiesUpserted = $activitiesUpserted
        DurationMs         = $durationMs
        Status             = $syncStatus
        ErrorMessage       = $syncError
    } | ConvertTo-Json -Compress

    Invoke-RestMethod -Uri "$dabBase/api/LogSync" -Method Post -Headers $dabHeaders -Body $logBody
    Write-Host "Sync log written: $syncStatus, ${durationMs}ms, $wellnessUpserted wellness, $activitiesUpserted activities"
} catch {
    Write-Host "WARNING: Failed to write sync log: $($_.Exception.Message)"
}

if ($syncStatus -eq 'Error') {
    throw "IntervalsSync failed: $syncError"
}

Write-Host "IntervalsSync completed successfully."

