-- Create the SyncLog table if it doesn't already exist.
IF NOT EXISTS (
    SELECT 1 FROM sys.tables
    WHERE name = 'SyncLog' AND schema_id = SCHEMA_ID('dbo')
)
BEGIN
    CREATE TABLE dbo.SyncLog (
        LogId              int            NOT NULL IDENTITY(1,1),
        RunAt              datetime2      NOT NULL DEFAULT GETUTCDATE(),
        Source             nvarchar(50)   NOT NULL DEFAULT 'IntervalsSync',  -- 'IntervalsSync' | 'CalorieSync'
        TriggerType        nvarchar(50)   NOT NULL,   -- 'Timer' | 'Manual' | 'CronJob'
        DateRangeStart     date           NULL,
        DateRangeEnd       date           NULL,
        WellnessFetched    int            NOT NULL DEFAULT 0,
        WellnessUpserted   int            NOT NULL DEFAULT 0,
        ActivitiesFetched  int            NOT NULL DEFAULT 0,
        ActivitiesUpserted int            NOT NULL DEFAULT 0,
        DurationMs         int            NULL,
        Status             nvarchar(20)   NOT NULL DEFAULT 'Success',  -- 'Success' | 'Error'
        ErrorMessage       nvarchar(2000) NULL,
        CONSTRAINT PK_SyncLog PRIMARY KEY (LogId)
    );
END;
ELSE
BEGIN
    -- Add Source column to existing table if it isn't already there.
    IF NOT EXISTS (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID('dbo.SyncLog') AND name = 'Source'
    )
    BEGIN
        ALTER TABLE dbo.SyncLog
            ADD Source nvarchar(50) NOT NULL DEFAULT 'IntervalsSync';
    END;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_LogSync
    @Source              nvarchar(50)   = 'IntervalsSync',
    @TriggerType         nvarchar(50)   = 'Timer',
    @DateRangeStart      date           = NULL,
    @DateRangeEnd        date           = NULL,
    @WellnessFetched     int            = 0,
    @WellnessUpserted    int            = 0,
    @ActivitiesFetched   int            = 0,
    @ActivitiesUpserted  int            = 0,
    @DurationMs          int            = NULL,
    @Status              nvarchar(20)   = 'Success',
    @ErrorMessage        nvarchar(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.SyncLog (
        Source, TriggerType, DateRangeStart, DateRangeEnd,
        WellnessFetched, WellnessUpserted,
        ActivitiesFetched, ActivitiesUpserted,
        DurationMs, Status, ErrorMessage
    )
    VALUES (
        @Source, @TriggerType, @DateRangeStart, @DateRangeEnd,
        @WellnessFetched, @WellnessUpserted,
        @ActivitiesFetched, @ActivitiesUpserted,
        @DurationMs, @Status, @ErrorMessage
    );
END;
