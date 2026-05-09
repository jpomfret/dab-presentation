{
  "$schema": "https://github.com/Azure/data-api-builder/releases/download/v0.10.23/dab.draft.schema.json",
  "data-source": {
    "database-type": "mssql",
    "connection-string": "@env('DATABASE_CONNECTION_STRING')"
  },
  "runtime": {
    "rest": {
      "enabled": true,
      "path": "/api",
      "request-body-strict": true
    },
    "graphql": {
      "enabled": true,
      "path": "/graphql",
      "allow-introspection": false
    },
    "host": {
      "cors": {
        "origins": [],
        "allow-credentials": false
      },
      "authentication": {
        "provider": "EntraID",
        "jwt": {
          "audience": "api://__APP_ID__",
          "issuer": "https://sts.windows.net/__TENANT_ID__/"
        }
      },
      "mode": "production"
    }
  },
  "entities": {
    "dbo_BuildVersion": {
      "source": {
        "object": "dbo.BuildVersion",
        "type": "table"
      },
      "graphql": {
        "enabled": true,
        "type": {
          "singular": "dbo_BuildVersion",
          "plural": "dbo_BuildVersions"
        }
      },
      "rest": {
        "enabled": true
      },
      "permissions": [
        {
          "role": "Authenticated",
          "actions": [
            { "action": "read" },
            { "action": "create" }
          ]
        }
      ]
    },
    "SalesLT_Customer": {
      "source": {
        "object": "SalesLT.Customer",
        "type": "table"
      },
      "graphql": {
        "enabled": true,
        "type": {
          "singular": "SalesLT_Customer",
          "plural": "SalesLT_Customers"
        }
      },
      "rest": {
        "enabled": true
      },
      "permissions": [
        {
          "role": "Authenticated",
          "actions": [
            { "action": "read" },
            { "action": "create" }
          ]
        }
      ]
    },
    "SalesLT_Product": {
      "source": {
        "object": "SalesLT.Product",
        "type": "table"
      },
      "graphql": {
        "enabled": true,
        "type": {
          "singular": "SalesLT_Product",
          "plural": "SalesLT_Products"
        }
      },
      "rest": {
        "enabled": true
      },
      "permissions": [
        {
          "role": "Authenticated",
          "actions": [
            { "action": "read" },
            { "action": "create" }
          ]
        }
      ]
    },
    "SalesLT_SalesOrderHeader": {
      "source": {
        "object": "SalesLT.SalesOrderHeader",
        "type": "table"
      },
      "graphql": {
        "enabled": true,
        "type": {
          "singular": "SalesLT_SalesOrderHeader",
          "plural": "SalesLT_SalesOrderHeaders"
        }
      },
      "rest": {
        "enabled": true
      },
      "permissions": [
        {
          "role": "Authenticated",
          "actions": [
            { "action": "read" },
            { "action": "create" }
          ]
        }
      ]
    },
    "UpsertWellness": {
      "source": {
        "object": "dbo.usp_UpsertWellness",
        "type": "stored-procedure",
        "parameters": {
          "RecordDate":   "2000-01-01",
          "CTL":          0.0,
          "ATL":          0.0,
          "RampRate":     0.0,
          "CTLLoad":      0.0,
          "ATLLoad":      0.0,
          "Weight":       0.0,
          "RestingHR":    0,
          "HRV":          0.0,
          "SleepSecs":    0,
          "SleepScore":   0.0,
          "SleepQuality": "",
          "Form":         "",
          "Updated":      ""
        }
      },
      "graphql": { "enabled": false },
      "rest": {
        "enabled": true,
        "methods": [ "post" ]
      },
      "permissions": [
        {
          "role": "Authenticated",
          "actions": [ "execute" ]
        }
      ]
    },
    "UpsertActivity": {
      "source": {
        "object": "dbo.usp_UpsertActivity",
        "type": "stored-procedure",
        "parameters": {
          "ActivityId":          "",
          "StartDateLocal":      "",
          "ActivityType":        "",
          "ActivityName":        "",
          "MovingTime":          0,
          "Distance":            0.0,
          "TrainingLoad":        0.0,
          "ATLLoad":             0.0,
          "CTLLoad":             0.0,
          "Intensity":           0.0,
          "AverageWatts":        0.0,
          "AverageHeartrate":    0.0,
          "TotalElevationGain":  0.0,
          "CTL":                 0.0,
          "ATL":                 0.0
        }
      },
      "graphql": { "enabled": false },
      "rest": {
        "enabled": true,
        "methods": [ "post" ]
      },
      "permissions": [
        {
          "role": "Authenticated",
          "actions": [ "execute" ]
        }
      ]
    },
    "LogSync": {
      "source": {
        "object": "dbo.usp_LogSync",
        "type": "stored-procedure",
        "parameters": {
          "TriggerType":         "Timer",
          "DateRangeStart":      "",
          "DateRangeEnd":        "",
          "WellnessFetched":     0,
          "WellnessUpserted":    0,
          "ActivitiesFetched":   0,
          "ActivitiesUpserted":  0,
          "DurationMs":          0,
          "Status":              "Success",
          "ErrorMessage":        ""
        }
      },
      "graphql": { "enabled": false },
      "rest": {
        "enabled": true,
        "methods": [ "post" ]
      },
      "permissions": [
        {
          "role": "Authenticated",
          "actions": [ "execute" ]
        }
      ]
    },
    "IntervalsWellness": {
      "source": {
        "object": "dbo.IntervalsWellness",
        "type": "table"
      },
      "graphql": {
        "enabled": true,
        "type": {
          "singular": "IntervalsWellness",
          "plural": "IntervalsWellnessList"
        }
      },
      "rest": {
        "enabled": true
      },
      "permissions": [
        {
          "role": "anonymous",
          "actions": [ { "action": "read" } ]
        },
        {
          "role": "Authenticated",
          "actions": [ { "action": "read" } ]
        }
      ]
    },
    "IntervalsActivity": {
      "source": {
        "object": "dbo.IntervalsActivity",
        "type": "table"
      },
      "graphql": {
        "enabled": true,
        "type": {
          "singular": "IntervalsActivity",
          "plural": "IntervalsActivities"
        }
      },
      "rest": {
        "enabled": true
      },
      "permissions": [
        {
          "role": "anonymous",
          "actions": [ { "action": "read" } ]
        },
        {
          "role": "Authenticated",
          "actions": [ { "action": "read" } ]
        }
      ]
    },
    "UpsertCalories": {
      "source": {
        "object": "dbo.usp_UpsertCalories",
        "type": "stored-procedure",
        "parameters": {
          "EntryDate":  "2000-01-01",
          "DailyTotal": 0,
          "Breakfast":  0,
          "Lunch":      0,
          "Snack":      0,
          "Dinner":     0,
          "Workout":    0,
          "Bedtime":    0
        }
      },
      "graphql": { "enabled": false },
      "rest": {
        "enabled": true,
        "methods": [ "post" ]
      },
      "permissions": [
        {
          "role": "Authenticated",
          "actions": [ "execute" ]
        }
      ]
    },
    "FuelGaugeCalories": {
      "source": {
        "object": "dbo.FuelGaugeCalories",
        "type": "table"
      },
      "graphql": {
        "enabled": true,
        "type": {
          "singular": "FuelGaugeCalories",
          "plural": "FuelGaugeCaloriesList"
        }
      },
      "rest": {
        "enabled": true
      },
      "permissions": [
        {
          "role": "anonymous",
          "actions": [ { "action": "read" } ]
        },
        {
          "role": "Authenticated",
          "actions": [ { "action": "read" } ]
        }
      ]
    }
  }
}
