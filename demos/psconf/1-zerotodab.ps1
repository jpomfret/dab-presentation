# install\update it locally?
dotnet tool install --global Microsoft.DataApiBuilder

# we need a local database
docker run -p 2500:1433 --volume shared:/shared:z --name mssql1 --hostname mssql1 -d dbatools/sqlinstance

# create a configuration
if (-not (Test-Path -Path C:\GitHub\dab-presentation\demos\config)) {
    New-Item -Path C:\GitHub\dab-presentation\demos\config -ItemType Directory
}
Set-Location -Path C:\GitHub\dab-presentation\demos\config

# use the dab cli
dab init --database-type "mssql" `
        --host-mode "Development" `
        --connection-string "Server=localhost,2500;User Id=sqladmin;Database=pubs;Password=dbatools.IO;TrustServerCertificate=True;Encrypt=True;"

# or create with mssql extension

code dab-config.json

# add an entity
dab add Author --source "dbo.authors" --permissions "anonymous:*"

# start dab

dab start

# go to the link
# swagger
# go to http://localhost:5000/api/Author

# call from PowerShell
$result = Invoke-RestMethod -Uri http://localhost:5000/api/Author -Method Get
$result.Value

# Can also post data - to insert a new author
$body = @{
    "au_id" = "999-56-7775"
    "au_fname" = "Jess"
    "au_lname" = "Pomfret"
    "contract" = "True"
} | ConvertTo-Json

$result = Invoke-RestMethod -Uri http://localhost:5000/api/Author -Method Post -Body $body -ContentType "application/json"
$result.Value

# problems? next steps! 
    # no auth?
    # connection string?
    # running locally

