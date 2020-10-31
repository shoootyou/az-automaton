################################################################################################
#region                         Azure Function - Initialization
################################################################################################
# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = Get-Date

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}
################################################################################################
#endregion                     Azure Function - Initialization
################################################################################################

Get-Module Az*