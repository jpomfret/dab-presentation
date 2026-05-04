CREATE OR ALTER PROCEDURE dbo.usp_UpsertActivity
    @ActivityId         nvarchar(50),
    @StartDateLocal     nvarchar(50)  = NULL,
    @ActivityType       nvarchar(50)  = NULL,
    @ActivityName       nvarchar(500) = NULL,
    @MovingTime         int           = NULL,
    @Distance           float         = NULL,
    @TrainingLoad       float         = NULL,
    @ATLLoad            float         = NULL,
    @CTLLoad            float         = NULL,
    @Intensity          float         = NULL,
    @AverageWatts       float         = NULL,
    @AverageHeartrate   float         = NULL,
    @TotalElevationGain float         = NULL,
    @CTL                float         = NULL,
    @ATL                float         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dbo.IntervalsActivity AS target
    USING (SELECT @ActivityId AS ActivityId) AS source
      ON target.ActivityId = source.ActivityId
    WHEN MATCHED THEN
        UPDATE SET
            StartDateLocal     = TRY_CONVERT(datetime2, @StartDateLocal),
            ActivityType       = @ActivityType,
            ActivityName       = @ActivityName,
            MovingTime         = @MovingTime,
            Distance           = @Distance,
            TrainingLoad       = @TrainingLoad,
            ATLLoad            = @ATLLoad,
            CTLLoad            = @CTLLoad,
            Intensity          = @Intensity,
            AverageWatts       = @AverageWatts,
            AverageHeartrate   = @AverageHeartrate,
            TotalElevationGain = @TotalElevationGain,
            CTL                = @CTL,
            ATL                = @ATL
    WHEN NOT MATCHED THEN
        INSERT (ActivityId, StartDateLocal, ActivityType, ActivityName, MovingTime,
                Distance, TrainingLoad, ATLLoad, CTLLoad, Intensity,
                AverageWatts, AverageHeartrate, TotalElevationGain, CTL, ATL)
        VALUES (@ActivityId, TRY_CONVERT(datetime2, @StartDateLocal), @ActivityType, @ActivityName, @MovingTime,
                @Distance, @TrainingLoad, @ATLLoad, @CTLLoad, @Intensity,
                @AverageWatts, @AverageHeartrate, @TotalElevationGain, @CTL, @ATL);
END;
