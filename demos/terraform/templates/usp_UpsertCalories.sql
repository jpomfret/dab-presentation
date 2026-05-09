-- Create FuelGaugeCalories table if it doesn't already exist.
IF NOT EXISTS (
    SELECT 1 FROM sys.tables
    WHERE name = 'FuelGaugeCalories' AND schema_id = SCHEMA_ID('dbo')
)
BEGIN
    CREATE TABLE dbo.FuelGaugeCalories (
        EntryDate   date      NOT NULL,
        DailyTotal  int       NOT NULL DEFAULT 0,
        Breakfast   int       NOT NULL DEFAULT 0,
        Lunch       int       NOT NULL DEFAULT 0,
        Snack       int       NOT NULL DEFAULT 0,
        Dinner      int       NOT NULL DEFAULT 0,
        Workout     int       NOT NULL DEFAULT 0,
        Bedtime     int       NOT NULL DEFAULT 0,
        InsertedAt  datetime2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt   datetime2 NOT NULL DEFAULT GETUTCDATE(),
        CONSTRAINT PK_FuelGaugeCalories PRIMARY KEY (EntryDate)
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_UpsertCalories
    @EntryDate  date,
    @DailyTotal int = 0,
    @Breakfast  int = 0,
    @Lunch      int = 0,
    @Snack      int = 0,
    @Dinner     int = 0,
    @Workout    int = 0,
    @Bedtime    int = 0
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dbo.FuelGaugeCalories AS target
    USING (SELECT @EntryDate AS EntryDate) AS source
      ON target.EntryDate = source.EntryDate
    WHEN MATCHED THEN
        UPDATE SET
            DailyTotal = @DailyTotal,
            Breakfast  = @Breakfast,
            Lunch      = @Lunch,
            Snack      = @Snack,
            Dinner     = @Dinner,
            Workout    = @Workout,
            Bedtime    = @Bedtime,
            UpdatedAt  = GETUTCDATE()
    WHEN NOT MATCHED THEN
        INSERT (EntryDate, DailyTotal, Breakfast, Lunch, Snack, Dinner, Workout, Bedtime)
        VALUES (@EntryDate, @DailyTotal, @Breakfast, @Lunch, @Snack, @Dinner, @Workout, @Bedtime);
END;
