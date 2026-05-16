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
#   DAB_ENDPOINT          — Base URL of the DAB container (e.g. https://host.azurecontainerapps.io)
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

# ── HttpClient for all DAB POST calls ─────────────────────────────────────────
# Invoke-RestMethod on Windows PS 7.4 uses WinHttpHandler, which throws
# InvalidOperationException against Azure Container Apps regardless of the
# transport setting. SocketsHttpHandler (used here explicitly) is the
# cross-platform handler and works reliably.
$handler                          = [System.Net.Http.SocketsHttpHandler]::new()
$dabClient                        = [System.Net.Http.HttpClient]::new($handler)
$dabClient.DefaultRequestVersion  = [System.Version]::new(1, 1)
$dabClient.DefaultVersionPolicy   = [System.Net.Http.HttpVersionPolicy]::RequestVersionOrLower

function Invoke-DabPost {
    param([string]$Uri, [string]$Token, [string]$Body)
    $content          = [System.Net.Http.StringContent]::new($Body, [System.Text.Encoding]::UTF8, 'application/json')
    $request          = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, $Uri)
    $request.Content  = $content
    $request.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $Token)
    $response = $dabClient.SendAsync($request).GetAwaiter().GetResult()
    if (-not $response.IsSuccessStatusCode) {
        $err = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        throw "DAB returned HTTP $([int]$response.StatusCode) $($response.ReasonPhrase): $err"
    }
}

# ── Basic auth header for intervals.icu (username is the literal "API_KEY") ───
$base64Creds      = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("API_KEY:$apiKey"))
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
$dabToken           = $null

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
    $identityEndpoint = $env:IDENTITY_ENDPOINT
    $identityHeader   = $env:IDENTITY_HEADER
    if (-not $identityEndpoint) { throw 'IDENTITY_ENDPOINT is not set — check the function app has a system-assigned managed identity enabled.' }
    if (-not $identityHeader)   { throw 'IDENTITY_HEADER is not set — check the function app has a system-assigned managed identity enabled.' }

    $tokenUri  = "${identityEndpoint}?api-version=2019-08-01&resource=api://$dabAppId"
    Write-Host "Acquiring token: $tokenUri"
    $tokenResp = Invoke-RestMethod -Uri $tokenUri -Headers @{ 'X-IDENTITY-HEADER' = $identityHeader }
    $dabToken  = $tokenResp.access_token
    Write-Host "Token acquired (expires $($tokenResp.expires_on))"

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

        Invoke-DabPost -Uri "$dabBase/api/UpsertWellness" -Token $dabToken -Body $body
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

        Invoke-DabPost -Uri "$dabBase/api/UpsertActivity" -Token $dabToken -Body $body
        $activitiesUpserted++
    }
    Write-Host "Upserted $activitiesUpserted activity records"

} catch {
    $syncStatus = 'Error'
    $syncError  = $_.Exception.Message
    Write-Host "IntervalsSync ERROR [$($_.Exception.GetType().FullName)]: $syncError"
    if ($_.Exception.InnerException) {
        Write-Host "  Inner: [$($_.Exception.InnerException.GetType().FullName)] $($_.Exception.InnerException.Message)"
    }
    Write-Host "  At: $($_.InvocationInfo.PositionMessage)"
}

# ── Write sync log via DAB ─────────────────────────────────────────────────────
# Runs whether the sync succeeded or failed so we always have a record.
try {
    $durationMs = [int]((Get-Date) - $startTime).TotalMilliseconds

    # Token may not have been acquired yet if the error was early — acquire now.
    if (-not $dabToken) {
        $identityEndpoint = $env:IDENTITY_ENDPOINT
        $identityHeader   = $env:IDENTITY_HEADER
        if ($identityEndpoint -and $identityHeader) {
            $tokenUri  = "${identityEndpoint}?api-version=2019-08-01&resource=api://$dabAppId"
            $tokenResp = Invoke-RestMethod -Uri $tokenUri -Headers @{ 'X-IDENTITY-HEADER' = $identityHeader }
            $dabToken  = $tokenResp.access_token
        }
    }

    if ($dabToken) {
        # $Timer.IsPastDue means the scheduled timer fired late — it does NOT indicate
        # a manual invocation. All timer-triggered runs are recorded as 'Timer'.
        $triggerType = 'Timer'

        $logBody = @{
            Source             = 'IntervalsSync'
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

        Invoke-DabPost -Uri "$dabBase/api/LogSync" -Token $dabToken -Body $logBody
        Write-Host "Sync log written: $syncStatus, ${durationMs}ms, $wellnessUpserted wellness, $activitiesUpserted activities"
    } else {
        Write-Host "WARNING: Skipping sync log — no token available."
    }
} catch {
    Write-Host "WARNING: Failed to write sync log: $($_.Exception.Message)"
} finally {
    $dabClient.Dispose()
}

if ($syncStatus -eq 'Error') {
    throw "IntervalsSync failed: $syncError"
}

Write-Host "IntervalsSync completed successfully."
