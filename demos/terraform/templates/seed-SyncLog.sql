-- =============================================================================
-- seed-SyncLog.sql
-- Populates dbo.SyncLog with realistic demo data for the DAB filter /
-- pagination demo. Generates ~220 rows spanning Nov 2025 – May 2026.
-- Safe to re-run: clears existing rows first so the demo stays repeatable.
-- =============================================================================

SET NOCOUNT ON;

-- Clear existing data so re-runs stay clean
DELETE FROM dbo.SyncLog;

-- Reset identity so LogId starts at 1
DBCC CHECKIDENT ('dbo.SyncLog', RESEED, 0);
GO

-- =============================================================================
-- Helper: insert one row
-- =============================================================================
DECLARE @i          int            = 0;
DECLARE @RunAt      datetime2;
DECLARE @Source     nvarchar(50);
DECLARE @Trigger    nvarchar(50);
DECLARE @Status     nvarchar(20);
DECLARE @Error      nvarchar(2000);
DECLARE @DurMs      int;
DECLARE @WellF      int;
DECLARE @WellU      int;
DECLARE @ActF       int;
DECLARE @ActU       int;
DECLARE @DRStart    date;
DECLARE @DREnd      date;

-- Base date: 180 days ago from a fixed reference so the demo is stable
DECLARE @BaseDate   datetime2 = DATEADD(DAY, -180, '2026-05-09T00:00:00');

WHILE @i < 220
BEGIN
    -- Spread rows across 180 days, roughly 1-2 per day
    SET @RunAt  = DATEADD(MINUTE,
                    CAST(RAND(CHECKSUM(NEWID())) * 180 * 24 * 60 AS int),
                    @BaseDate);

    -- Source: 60% IntervalsSync, 40% CalorieSync
    SET @Source = CASE WHEN @i % 5 IN (0,1,2) THEN 'IntervalsSync' ELSE 'CalorieSync' END;

    -- TriggerType: mostly Timer, occasional Manual
    SET @Trigger = CASE
        WHEN @i % 12 = 0 THEN 'Manual'
        WHEN @i % 12 = 1 THEN 'CronJob'
        ELSE 'Timer'
    END;

    -- DateRange: last 7 days from RunAt
    SET @DRStart = CAST(DATEADD(DAY, -7, @RunAt) AS date);
    SET @DREnd   = CAST(@RunAt AS date);

    -- Status: ~8% Error rate, sprinkled at specific intervals for demo clarity
    SET @Status = CASE
        WHEN @i IN (3, 17, 31, 44, 58, 72, 89, 103, 115, 128, 141, 156, 170, 184, 198, 210) THEN 'Error'
        ELSE 'Success'
    END;

    -- Duration: Success 800–4500 ms, Error shorter (failed fast) or longer (timed out)
    SET @DurMs = CASE @Status
        WHEN 'Success' THEN 800  + CAST(RAND(CHECKSUM(NEWID())) * 3700 AS int)
        ELSE                 200  + CAST(RAND(CHECKSUM(NEWID())) * 8000 AS int)
    END;

    -- Record counts (only meaningful for IntervalsSync; CalorieSync has 0 wellness)
    IF @Source = 'IntervalsSync' AND @Status = 'Success'
    BEGIN
        SET @WellF = 7  + CAST(RAND(CHECKSUM(NEWID())) * 7  AS int);
        SET @WellU = @WellF - CAST(RAND(CHECKSUM(NEWID())) * 3 AS int);
        SET @ActF  = 3  + CAST(RAND(CHECKSUM(NEWID())) * 12 AS int);
        SET @ActU  = @ActF  - CAST(RAND(CHECKSUM(NEWID())) * 2 AS int);
    END
    ELSE IF @Source = 'CalorieSync' AND @Status = 'Success'
    BEGIN
        SET @WellF = 0; SET @WellU = 0;
        SET @ActF  = 0; SET @ActU  = 0;
    END
    ELSE
    BEGIN
        SET @WellF = 0; SET @WellU = 0;
        SET @ActF  = 0; SET @ActU  = 0;
    END;

    -- Error messages
    SET @Error = CASE @Status
        WHEN 'Error' THEN
            CASE (@i % 5)
                WHEN 0 THEN 'HTTP 429 Too Many Requests — Intervals.icu rate limit exceeded. Retry after 60s.'
                WHEN 1 THEN 'Connection timeout after 30000ms. SQL Server did not respond in time.'
                WHEN 2 THEN 'Deserialization error: unexpected null in field ''RecordDate'' at row 4.'
                WHEN 3 THEN 'HTTP 503 Service Unavailable — upstream API returned empty body.'
                ELSE        'Unhandled exception: Object reference not set to an instance of an object.'
            END
        ELSE NULL
    END;

    INSERT INTO dbo.SyncLog (
        RunAt, Source, TriggerType,
        DateRangeStart, DateRangeEnd,
        WellnessFetched, WellnessUpserted,
        ActivitiesFetched, ActivitiesUpserted,
        DurationMs, Status, ErrorMessage
    )
    VALUES (
        @RunAt, @Source, @Trigger,
        @DRStart, @DREnd,
        @WellF, @WellU,
        @ActF, @ActU,
        @DurMs, @Status, @Error
    );

    SET @i = @i + 1;
END;

-- Quick summary so you can verify the seed worked
SELECT
    Status,
    Source,
    COUNT(*)       AS Rows,
    MIN(RunAt)     AS Earliest,
    MAX(RunAt)     AS Latest,
    AVG(DurationMs) AS AvgDurationMs
FROM dbo.SyncLog
GROUP BY Status, Source
ORDER BY Source, Status;
GO
