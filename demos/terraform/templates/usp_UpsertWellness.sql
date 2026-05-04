CREATE OR ALTER PROCEDURE dbo.usp_UpsertWellness
    @RecordDate   date,
    @CTL          float         = NULL,
    @ATL          float         = NULL,
    @RampRate     float         = NULL,
    @CTLLoad      float         = NULL,
    @ATLLoad      float         = NULL,
    @Weight       float         = NULL,
    @RestingHR    int           = NULL,
    @HRV          float         = NULL,
    @SleepSecs    int           = NULL,
    @SleepScore   float         = NULL,
    @SleepQuality nvarchar(50)  = NULL,
    @Form         nvarchar(50)  = NULL,
    @Updated      nvarchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dbo.IntervalsWellness AS target
    USING (SELECT @RecordDate AS RecordDate) AS source
      ON target.RecordDate = source.RecordDate
    WHEN MATCHED THEN
        UPDATE SET
            CTL          = @CTL,
            ATL          = @ATL,
            TSB          = CASE WHEN @CTL IS NOT NULL AND @ATL IS NOT NULL THEN @CTL - @ATL ELSE NULL END,
            RampRate     = @RampRate,
            CTLLoad      = @CTLLoad,
            ATLLoad      = @ATLLoad,
            Weight       = @Weight,
            RestingHR    = @RestingHR,
            HRV          = @HRV,
            SleepSecs    = @SleepSecs,
            SleepScore   = @SleepScore,
            SleepQuality = @SleepQuality,
            Form         = @Form,
            Updated      = TRY_CONVERT(datetime2, @Updated)
    WHEN NOT MATCHED THEN
        INSERT (RecordDate, CTL, ATL, TSB, RampRate, CTLLoad, ATLLoad,
                Weight, RestingHR, HRV, SleepSecs, SleepScore, SleepQuality, Form, Updated)
        VALUES (@RecordDate, @CTL, @ATL,
                CASE WHEN @CTL IS NOT NULL AND @ATL IS NOT NULL THEN @CTL - @ATL ELSE NULL END,
                @RampRate, @CTLLoad, @ATLLoad,
                @Weight, @RestingHR, @HRV, @SleepSecs, @SleepScore, @SleepQuality, @Form,
                TRY_CONVERT(datetime2, @Updated));
END;
