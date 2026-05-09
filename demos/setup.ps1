# docker container
# tests?

# remove config folder if exists
if ((Test-Path -Path C:\GitHub\dab-presentation\demos\config)) {
    Remove-Item -Path C:\GitHub\dab-presentation\demos\config -Recurse
}