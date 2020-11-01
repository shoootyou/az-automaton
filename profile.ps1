# Azure Functions profile.ps1
#
# This profile.ps1 will get executed every "cold start" of your Function App.
# "cold start" occurs when:
#
# * A Function App starts up for the very first time
# * A Function App starts up after being de-allocated due to inactivity
#
# You can define helper functions, run commands, or specify environment variables
# NOTE: any variables defined that are not environment variables will get reset after the first execution

# Authenticate with Azure PowerShell using MSI.
# Remove this if you are not planning on using MSI or Azure PowerShell.

Remove-Module Az.Accounts -ErrorAction SilentlyContinue
Import-Module Az.Accounts -RequiredVersion 1.9.5 -Force -ErrorAction SilentlyContinue
Import-Module Az.Advisor
Import-Module Az.Compute
Import-Module Az.Security
Import-Module Az.Sql
Import-Module Az.Storage
Import-Module AzTable
Import-Module AzureAD -UseWindowsPowerShell

if ($env:MSI_SECRET -and (Get-Module -ListAvailable Az.Accounts)) {
    Connect-AzAccount -Identity
}

# Uncomment the next line to enable legacy AzureRm alias in Azure PowerShell.
# Enable-AzureRmAlias

# You can also define functions or aliases that can be referenced in any of your PowerShell functions.
