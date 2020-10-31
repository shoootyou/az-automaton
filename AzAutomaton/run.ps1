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

$ErrorActionPreference = "Stop"
$WarningPreference = "SilentlyContinue"

Write-Host $currentUTCtime

$INT_CT_TBL_CLI = New-AzStorageContext -ConnectionString $ENV:AzAu_ClientConnectionString
$INT_NM_TBL_CLI = Get-AzStorageTable -Context $INT_CT_TBL_CLI -Name "amasterclients" -ErrorAction SilentlyContinue
$INT_DB_TBL_SUB = Get-AzTableRow -Table $INT_NM_TBL_CLI.CloudTable -PartitionKey "Clients" | Sort-Object TableTimestamp -Descending

Write-Host "Control 0"

Import-Module AzureAD -UseWindowsPowerShell 
Remove-Variable MAS_CLI -ErrorAction SilentlyContinue

foreach($MAS_CLI in $INT_DB_TBL_SUB ) {
    Clear-AzContext -Force -ErrorAction SilentlyContinue
    ################################################################################################
    #region                                 Login process
    ################################################################################################

    Remove-Variable ITM_SUB -ErrorAction SilentlyContinue
    Remove-Variable COR_AZ_SUB_ALL -ErrorAction SilentlyContinue
    Remove-Variable COR_AZ_RES_ALL -ErrorAction SilentlyContinue
    
    Write-Host "Control 1"
    $COR_AZ_RES_ALL = Connect-AzAccount -CertificateThumbprint $ENV:AzAu_CertificateThumbprint -ApplicationId $ENV:AzAu_ApplicationId -Tenant $MAS_CLI.TenantId -ServicePrincipal
    $MAS_CLI
    $COR_AZ_RES_ALL.Context | Select *
    $TNT_ID = $COR_AZ_RES_ALL.Context.Tenant.Id
        
    ################################################################################################
    #endregion                              Login process
    ################################################################################################
    #Set-AzContext -Tenant $COR_AZ_RES_ALL.Context.Tenant.Id
    $COR_AZ_SUB_ALL = Get-AzSubscription -TenantId $MAS_CLI.TenantId | Select-Object *
    #$COR_AZ_SUB_ALL.TenantId
    ################################################################################################
    #region                                 Process Section
    ################################################################################################
    foreach ($ITM_SUB in $COR_AZ_SUB_ALL){
        Write-Host "Control 2"
        Write-Host "Trabajando en: " $MAS_CLI.RowKey " | " $ITM_SUB.Name " | " $ITM_SUB.SubscriptionId " | " $ITM_SUB.TenantId -ForegroundColor DarkGreen
        ################################################################################################
        #region                      Initialization Variables and Information
        ################################################################################################
        
        $COR_AZ_TNT_ALL = Connect-AzureAD -CertificateThumbprint $ENV:AzAu_CertificateThumbprint -ApplicationId $ENV:AzAu_ApplicationId -TenantId $ITM_SUB.TenantId
        $ITM_SUB
        $COR_AZ_TNT_ALL

    }
    ################################################################################################
    #endregion                              Process Section
    ################################################################################################

    
}