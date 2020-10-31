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
$INT_DB_TBL_SUB = Get-AzTableRow -Table $INT_NM_TBL_CLI.CloudTable -PartitionKey "Clients" | Sort-Object TableTimestamp 

Write-Host "Control 0"

Remove-Variable MAS_CLI -ErrorAction SilentlyContinue

################################################################################################
#endregion                         Get Client information
################################################################################################

foreach($MAS_CLI in $INT_DB_TBL_SUB ) {
    
    ################################################################################################
    #region                                 Login process
    ################################################################################################

    Remove-Variable ITM_SUB -ErrorAction SilentlyContinue
    Remove-Variable COR_AZ_SUB_ALL -ErrorAction SilentlyContinue
    Remove-Variable COR_AZ_RES_ALL -ErrorAction SilentlyContinue
    
    Write-Host "Control 1"
    $COR_AZ_RES_ALL = Connect-AzAccount -CertificateThumbprint $ENV:AzAu_CertificateThumbprint -ApplicationId $ENV:AzAu_ApplicationId -Tenant $MAS_CLI.TenantId -ServicePrincipal
    #$COR_AZ_RES_ALL
    $TNT_ID = $COR_AZ_RES_ALL.Context.Tenant.Id
        
    ################################################################################################
    #endregion                              Login process
    ################################################################################################
    Set-AzContext -Tenant $COR_AZ_RES_ALL.Context.Tenant.Id
    $COR_AZ_SUB_ALL = Get-AzSubscription -TenantId $COR_AZ_RES_ALL.Context.Tenant.Id | Select-Object *
    $COR_AZ_SUB_ALL.TenantId
    ################################################################################################
    #region                                 Process Section
    ################################################################################################
    foreach ($ITM_SUB in $COR_AZ_SUB_ALL){
        Write-Host "Control 2"
        Write-Host "Trabajando en: " $MAS_CLI.RowKey " | " $ITM_SUB.Name " | " $ITM_SUB.SubscriptionId " | " $ITM_SUB.TenantId -ForegroundColor DarkGreen
        ################################################################################################
        #region                      Initialization Variables and Information
        ################################################################################################
        $ITM_SUB
        Import-Module AzureAD -UseWindowsPowerShell 
        $COR_AZ_TNT_ALL = Connect-AzureAD -CertificateThumbprint $ENV:AzAu_CertificateThumbprint -ApplicationId $ENV:AzAu_ApplicationId -TenantId $ITM_SUB.TenantId
        $GBL_IN_FOR_CNT = 1
        $GBL_IN_SUB_CNT = 0

        ################################################################################################
        #endregion                   Initialization Variables and Information
        ################################################################################################

        $WR_BAR = $ITM_SUB.Name
        Write-Host $GBL_IN_SUB_CNT "- Inicializacion de datos para subscripcion" $ITM_SUB.SubscriptionId -ForegroundColor DarkGray

        $GBL_IN_SUB_CNT++
    }
    ################################################################################################
    #endregion                              Process Section
    ################################################################################################

    <################################################################################################
    #region                     Azure Function - Teams reporting
    ################################################################################################

    $JSONBody = [PSCustomObject][Ordered]@{
    "@type"      = "MessageCard"
    "@context"   = "http://schema.org/extensions"
    "summary"    = "AzAutomaton"
    "themeColor" = '0078D7'
    "sections"   = @(
        @{
            "activityTitle"    = "<h1>Actualizacion de reporte</h1>"
            "activitySubtitle" = "Se envia actualizacion de reporte de recursos en Azure - Power BI"
            "activityImage" = "https://cdn0.iconfinder.com/data/icons/website-design-4/467/Protection_icon-512.png"
            "facts"            = @(
                @{
                    "name"  = "Cliente"
                    "value" = $MAS_CLI.RowKey
                },
                @{
                    "name"  = "Dominio interno"
                    "value" = $COR_AZ_TNT_ALL.TenantDomain
                },
                @{
                    "name"  = "ID de Tenant (Azure AD)"
                    "value" = $ITM_SUB.TenantId
                },
                @{
                    "name"  = "Suscripciones revisadas"
                    "value" = '<blockquote>' + ($COR_AZ_SUB_ALL.Name -join ' <br> ') + '</blockquote>'
                },
                @{
                    "name"  = "URL de Reporte"
                    "value" = ('<a href=' + $ENV:AzAu_PowerBIReport + '>AzAutomaton - PowerBI Report</a>')
                }
            )
                    "markdown" = $false
        }
    )
    }

    $TeamMessageBody = ConvertTo-Json $JSONBody -Depth 100

    $parameters = @{
    "URI"         = $ENV:AzAu_TeamsConnection
    "Method"      = 'POST'
    "Body"        = $TeamMessageBody
    "ContentType" = 'application/json'
    }

    Invoke-RestMethod @parameters

    ################################################################################################
    #endregion                  Azure Function - Teams reporting
    ################################################################################################>
    
}
Write-Host "Proceso finalizado" -ForegroundColor DarkGreen