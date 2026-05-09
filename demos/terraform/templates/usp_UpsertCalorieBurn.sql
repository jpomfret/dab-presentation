-- Create FuelGaugeCalorieBurn table if it doesn't already exist.
IF NOT EXISTS (
    SELECT 1 FROM sys.tables
    WHERE name = 'FuelGaugeCalorieBurn' AND schema_id = SCHEMA_ID('dbo')
)
BEGIN
    CREATE TABLE dbo.FuelGaugeCalorieBurn (
        EntryDate        date      NOT NULL,
        BmrCalories      int       NOT NULL DEFAULT 0,
        ActivityCalories int       NOT NULL DEFAULT 0,
        InsertedAt       datetime2 NOT NULL DEFAULT GETUTCDATE(),
        UpdatedAt        datetime2 NOT NULL DEFAULT GETUTCDATE(),
        CONSTRAINT PK_FuelGaugeCalorieBurn PRIMARY KEY (EntryDate)
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_UpsertCalorieBurn
    @EntryDate        date,
    @BmrCalories      int = 0,
    @ActivityCalories int = 0
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dbo.FuelGaugeCalorieBurn AS target
    USING (SELECT @EntryDate AS EntryDate) AS source
      ON target.EntryDate = source.EntryDate
    WHEN MATCHED THEN
        UPDATE SET
            BmrCalories      = @BmrCalories,
            ActivityCalories = @ActivityCalories,
            UpdatedAt        = GETUTCDATE()
    WHEN NOT MATCHED THEN
        INSERT (EntryDate, BmrCalories, ActivityCalories)
        VALUES (@EntryDate, @BmrCalories, @ActivityCalories);
END;
