# install\update it locally?
dotnet tool install --global Microsoft.DataApiBuilder

# get a container?

# we need a local database

docker run -p 2500:1433 --volume shared:/shared:z --name mssql1 --hostname mssql1 -d dbatools/sqlinstance

# create a configuration
New-Item -Path config -ItemType Directory
Set-Location -Path config
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
$result = Invoke-WebRequest -Uri http://localhost:5000/api/Author -Method Get
($result.Content | ConvertFrom-Json).Value

# problems? next steps! 
    # no auth?
    # connection string?
    # running locally
