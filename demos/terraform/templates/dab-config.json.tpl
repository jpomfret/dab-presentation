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
      "allow-introspection": true
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
      "mode": "development"
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
    }
  }
}
