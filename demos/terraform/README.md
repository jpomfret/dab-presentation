# DAB Presentation — Terraform

Terraform configuration to provision the full Azure environment for the Data API Builder (DAB) demo series. Deploys a DAB container fronting an Azure SQL Database, locked down with Entra authentication, and callable from an Azure Function App.

## Prerequisites

The following must be installed and available on the machine running `terraform apply`:

| Tool | Purpose |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5 | Infrastructure provisioning |
| [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az`) | Used by `null_resource` provisioners to set the app identifier URI, create the SQL database user for the container MI, and configure the function app setting |
| `Invoke-Sqlcmd` ([SqlServer module](https://www.powershellgallery.com/packages/SqlServer)) | Creates the Entra-based SQL user for the container's managed identity — requires `Install-Module SqlServer` |

You must be logged into the Azure CLI with an account that is a member of the Entra group set as SQL external admin (so it can create Entra-based database users):

```powershell
az login
az account set --subscription "<your-subscription-id>"
```

## Quick start

```powershell
# 1. Copy and fill in your values
Copy-Item terraform.tfvars.example terraform.tfvars

# 2. Initialise providers
terraform init

# 3. Review the plan
terraform plan -out 'plan.tfplan'

# 4. Apply (takes ~5-10 minutes)
terraform apply "plan.tfplan"
```

After apply, the outputs include the DAB API endpoint, Swagger URL, and a ready-to-paste PowerShell command to get a user token for testing.

## File overview

| File | Purpose |
|---|---|
| `main.tf` | Provider requirements (`azurerm ~> 4.0`, `azuread ~> 3.0`, `random`) and resource group |
| `variables.tf` | All input variables — subscription ID, SQL credentials, resource names, Entra admin group |
| `locals.tf` | Computed values: MSI connection string, DAB endpoint URL, tenant ID |
| `sql.tf` | Azure SQL Server (with Entra external admin), serverless GP_S_Gen5_2 database seeded with AdventureWorksLT, firewall rule allowing Azure services, and a `null_resource` that creates the container MI as a database user with `db_datareader`/`db_datawriter` |
| `storage.tf` | Storage account and file share, plus a `null_resource` that renders `templates/dab-config.json.tpl` (substitutes app ID and tenant ID) and uploads it to the share |
| `container.tf` | Azure Container Instance running DAB — mounts the config file share, sets the connection string env var, system-assigned MI, and a `null_resource` restart after the DB user is provisioned |
| `function.tf` | Consumption App Service Plan and Windows Function App (PowerShell 7.4, Functions v4), plus a `null_resource` to set `AZURE_CLIENT_ID` after the MI is created |
| `entra.tf` | Entra App Registration (`DAB-API-Access`) with `DAB.Access` app role, `user_impersonation` delegated scope, Azure CLI pre-authorization, service principal, and app role assignment granting the function MI access |
| `outputs.tf` | DAB API endpoint, Swagger URL, function hostname, managed identity principal IDs, token command |
| `templates/dab-config.json.tpl` | DAB configuration template — authentication block and key AdventureWorksLT entities; `__APP_ID__` and `__TENANT_ID__` are replaced at apply time |
| `terraform.tfvars.example` | Example variable values to copy and fill in |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Azure                                              │
│                                                     │
│  ┌──────────────┐    MSI auth    ┌───────────────┐  │
│  │  Container   │──────────────▶│  Azure SQL DB  │  │
│  │  Instance    │                │ (AdventureWks) │  │
│  │  (DAB :5000) │                └───────────────┘  │
│  └──────┬───────┘                                   │
│         │ mounts                                    │
│  ┌──────▼───────┐                                   │
│  │  File Share  │  dab-config.json                  │
│  │  (Storage)   │  (auth + entities)                │
│  └──────────────┘                                   │
│                                                     │
│  ┌──────────────┐  Bearer token  ┌───────────────┐  │
│  │  Function    │──────────────▶│  DAB API      │  │
│  │  App         │                │  (Container)  │  │
│  │  (PowerShell)│                └───────────────┘  │
│  └──────────────┘                                   │
└─────────────────────────────────────────────────────┘

Entra: DAB-API-Access app registration
  - DAB.Access app role  → assigned to Function App MI
  - user_impersonation scope → pre-authorized for Azure CLI
```

## Notes

**`identifier_uris` is set in two steps** — the app registration is created first, then `az ad app update` sets `api://<client_id>` via a `null_resource`, because the client ID is only known after creation.

**`AZURE_CLIENT_ID` function setting** — same pattern: set via `null_resource` after the function app's managed identity is created. A `lifecycle.ignore_changes` rule prevents Terraform from overwriting it on subsequent applies.

**SQL database user** — the `null_resource` in `sql.tf` uses your active `az` session (must be an Entra admin on the SQL server) to create the container's MI as a SQL user. This cannot be done with a SQL login — it requires an Entra-authenticated connection.

## Tidy up

```powershell
terraform destroy
# Entra resources are outside the resource group and must be removed separately
az ad app delete --id <app_registration_client_id>
```
