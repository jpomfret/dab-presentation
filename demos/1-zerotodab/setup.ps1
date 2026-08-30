# docker container
# tests?

# remove config folder if exists
if ((Test-Path -Path C:\GitHub\dab-presentation\demos\config)) {
    Remove-Item -Path C:\GitHub\dab-presentation\demos\config -Recurse -Force
}

# remove container
docker rm mssql1 -f

# open a new pwsh in terminal so we have two and it's ready to go

# open https://kind-pebble-091bf8b03.7.azurestaticapps.net/index.html so it's loaded and awake
