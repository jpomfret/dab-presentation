# profile.ps1 — intentionally minimal.
# This function does not use Az PowerShell cmdlets; tokens are acquired via
# the IDENTITY_ENDPOINT REST endpoint. An empty profile avoids the Az.Accounts
# cold-start race where Disable-AzContextAutosave / Connect-AzAccount fail
# because managed dependencies haven't finished installing yet.
