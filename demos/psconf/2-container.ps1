# DAB via the official Microsoft container image
# No dotnet tooling required — just Docker

# Make sure you stopped the running dab session!

# pull the image
docker pull mcr.microsoft.com/azure-databases/data-api-builder

# we still need a local database (reuse from demo 1 if already running)
docker run -p 2500:1433 --volume shared:/shared:z --name mssql1 --hostname mssql1 -d dbatools/sqlinstance

# create a config directory and generate a dab-config.json
# (reuse the CLI if installed, or reference the one already created in demo 1)
if (-not (Test-Path -Path C:\GitHub\dab-presentation\demos\config)) {
    New-Item -Path C:\GitHub\dab-presentation\demos\config -ItemType Directory
}
Set-Location -Path C:\GitHub\dab-presentation\demos\config

# remove existing config if present
if (Test-Path -Path .\dab-config.json) {
    Remove-Item -Path .\dab-config.json
}

# store the connection string as a variable — never hardcoded in the config
$CONN_STR = "Server=host.docker.internal,2500;User Id=sqladmin;Database=pubs;Password=dbatools.IO;TrustServerCertificate=True;Encrypt=True;"

# note: inside the container, 'localhost' refers to the container itself,
# so we use host.docker.internal to reach SQL Server on the host machine
# @env('CONN_STR') tells DAB to resolve the value from the environment at runtime
dab init --database-type "mssql" `
        --host-mode "Development" `
        --connection-string "@env('CONN_STR')"

# add an entity
dab add Author --source "dbo.authors" --permissions "anonymous:read"

# review the config
code dab-config.json

# start DAB using the Microsoft container image
# -p 5000:5000   — map port 5000 on the host to port 5000 in the container
# -v             — mount the local config folder into the container
docker run -it --rm `
    -p 5000:5000 `
    -v "C:\GitHub\dab-presentation\demos\config:/App/dab-config" `
    -e "CONN_STR=$CONN_STR" `
    mcr.microsoft.com/azure-databases/data-api-builder `
    --ConfigFileName /App/dab-config/dab-config.json

# go to http://localhost:5000/api/Author

# call from PowerShell
$result = Invoke-RestMethod -Uri http://localhost:5000/api/Author -Method Get
$result.Value

# But can't post data, only read access
$body = @{
    "au_id" = "999-56-9999"
    "au_fname" = "Jess"
    "au_lname" = "Pomfret"
    "contract" = "True"
} | ConvertTo-Json

Invoke-RestMethod -Uri http://localhost:5000/api/Author -Method Post -Body $body -ContentType "application/json"

# next steps
# create an Azure Container App running DAB in production mode with Entra ID auth
# create Azure File Share & upload config
# mount the file share in the container app to read the config
