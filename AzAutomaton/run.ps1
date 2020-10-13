################################################################################################
#region                         Azure Function - Initialization
################################################################################################
# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}
################################################################################################
#endregion                     Azure Function - Initialization
################################################################################################

$ErrorActionPreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"

Write-Host $currentUTCtime

$INT_CT_TBL_CLI = New-AzStorageContext -ConnectionString $ENV:AzAu_ClientConnectionString
$INT_NM_TBL_CLI = Get-AzStorageTable -Context $INT_CT_TBL_CLI -Name "amasterclients" -ErrorAction SilentlyContinue
$INT_DB_TBL_SUB = Get-AzTableRow -Table $INT_NM_TBL_CLI.CloudTable -PartitionKey "Clients" | Sort-Object TableTimestamp 

Write-Host "Control 0"

$OUT_TBL_CTX = New-AzStorageContext -ConnectionString $ENV:AzAu_ConnectionString
$OUT_DB_TBL_SUB = Get-AzStorageTable -Context $OUT_TBL_CTX -ErrorAction SilentlyContinue
$OUT_DB_TBL_SUB | ForEach-Object -Parallel {
    $OUT_TBL_CTX = New-AzStorageContext -ConnectionString "DefaultEndpointsProtocol=https;AccountName=orionazreport02;AccountKey=3RTD51FviKOrg2kTg+eQzibQWGwvI/SMmaSOcffdjE1/uktSsJl9Qt6L4E9j2jSHBbHzBMoEfDyaHeUZlU6tQw==;EndpointSuffix=core.windows.net"
    Write-Host $_.Name
    Remove-AzStorageTable –Name $_.Name –Context $OUT_TBL_CTX -Confirm:$false -Force -ErrorAction SilentlyContinue
}

################################################################################################
#endregion                         Get Client information
################################################################################################

foreach($MAS_CLI in $INT_DB_TBL_SUB ) {
    
    ################################################################################################
    #region                                 Login process
    ################################################################################################
    Write-Host "Control 1"
    $COR_AZ_RES_ALL = Connect-AzAccount -CertificateThumbprint $ENV:AzAu_CertificateThumbprint -ApplicationId $ENV:AzAu_ApplicationId -Tenant $MAS_CLI.TenantId -ServicePrincipal
    $TNT_ID = $COR_AZ_RES_ALL.Context.Tenant.Id
        
    ################################################################################################
    #endregion                              Login process
    ################################################################################################

    $COR_AZ_SUB_ALL = Get-AzSubscription -TenantId $TNT_ID | Select-Object *

    ################################################################################################
    #region                                 Process Section
    ################################################################################################
    foreach ($SUB in $COR_AZ_SUB_ALL){
        Write-Host "Control 2"
        Write-Host $MAS_CLI.RowKey " | " $SUB.Name " | " $SUB.SubscriptionId " | " $SUB.TenantId 
        ################################################################################################
        #region                      Initialization Variables and Information
        ################################################################################################
        
        Import-Module AzureAD -UseWindowsPowerShell 
        $COR_AZ_TNT_ALL = Connect-AzureAD -CertificateThumbprint $ENV:AzAu_CertificateThumbprint -ApplicationId $ENV:AzAu_ApplicationId -TenantId $SUB.TenantId
        $GBL_IN_FOR_CNT = 1
        $GBL_IN_SUB_CNT = 0

        ################################################################################################
        #endregion                   Initialization Variables and Information
        ################################################################################################

        $WR_BAR = $SUB.Name
        Write-Host $GBL_IN_SUB_CNT "- Inicializacion de datos para subscripcion" $SUB.SubscriptionId -ForegroundColor DarkGray
        
        if($SUB.State -ne "Enabled" -or $SUB.Name -like "*Azure Active Directory"){
            if($SUB.Name -like "*Azure Active Directory"){
                Write-Host "    A. Suscripcion deshabilitada" -ForegroundColor Cyan    
            }
            else{
                Write-Host "    A. Suscripcion deshabilitada" -ForegroundColor Cyan    
                Start-Sleep -Seconds 10    
            }
        }
        else{

            ################################################################################################
            #region                           Master Tables preparation
            ################################################################################################

            $OUT_TBL_CTX = New-AzStorageContext -ConnectionString $ENV:AzAu_ConnectionString

            Write-Host "1 - Creacion de tablas maestras de recursos" -ForegroundColor DarkGray

            $OUT_DB_TBL_SUB =  Get-AzStorageTable -Context $OUT_TBL_CTX -Name "amastersubscription" -ErrorAction SilentlyContinue
            if(!$OUT_DB_TBL_SUB){
                Start-Sleep -Seconds 10
                $OUT_DB_TBL_SUB = New-AzStorageTable -Context $OUT_TBL_CTX -Name "amastersubscription"
            }
            Write-Host "        Tabla de listado de suscripciones creada exitosamente" -ForegroundColor Green

            $OUT_DB_TBL_RSG =  Get-AzStorageTable -Context $OUT_TBL_CTX -Name "amasterresourcegroup" -ErrorAction SilentlyContinue
            if(!$OUT_DB_TBL_RSG){
                Start-Sleep -Seconds 10
                $OUT_DB_TBL_RSG = New-AzStorageTable -Context $OUT_TBL_CTX -Name "amasterresourcegroup"
            }
            Write-Host "        Tabla de listado de grupo de recursos creada exitosamente" -ForegroundColor Green

            $OUT_DB_TBL_REG =  Get-AzStorageTable -Context $OUT_TBL_CTX -Name "amasterregions" -ErrorAction SilentlyContinue
            if(!$OUT_DB_TBL_REG){
                Start-Sleep -Seconds 10
                $OUT_DB_TBL_REG = New-AzStorageTable -Context $OUT_TBL_CTX -Name "amasterregions"
            }
            Write-Host "        Tabla de listado de regiones creada exitosamente" -ForegroundColor Green

            $OUT_DB_TBL_RES =  Get-AzStorageTable -Context $OUT_TBL_CTX -Name "amasterresources" -ErrorAction SilentlyContinue
            if(!$OUT_DB_TBL_RES){
                Start-Sleep -Seconds 10
                $OUT_DB_TBL_RES = New-AzStorageTable -Context $OUT_TBL_CTX -Name "amasterresources"
            }
            Write-Host "        Tabla de listado de informacion general de recursos creada exitosamente" -ForegroundColor Green

            $OUT_DB_TBL_REC =  Get-AzStorageTable -Context $OUT_TBL_CTX -Name "amasterrecommendations" -ErrorAction SilentlyContinue
            if(!$OUT_DB_TBL_REC){
                Start-Sleep -Seconds 10
                $OUT_DB_TBL_REC = New-AzStorageTable -Context $OUT_TBL_CTX -Name "amasterrecommendations"
            }
            Write-Host "        Tabla de listado de recomendaciones de Azure Advisor creada exitosamente" -ForegroundColor Green

            $OUT_DB_TBL_PER =  Get-AzStorageTable -Context $OUT_TBL_CTX -Name "amasterpermissions" -ErrorAction SilentlyContinue
            if(!$OUT_DB_TBL_PER){
                Start-Sleep -Seconds 10
                $OUT_DB_TBL_PER = New-AzStorageTable -Context $OUT_TBL_CTX -Name "amasterpermissions"
            }
            Write-Host "        Tabla de listado de permisos sobre subscripciones creada exitosamente" -ForegroundColor Green

            ################################################################################################
            #endregion                        Master Tables preparation
            ################################################################################################

            #region selección de subscripción y recursos
            Write-Host "    A. Obtencion de informacion de subscripciones y recursos" -ForegroundColor Cyan
            Select-AzSubscription -Subscription $SUB.SubscriptionId | Out-Null
            $DB_AZ_RES_ALL = Get-AzResource | Select-Object * | Sort-Object Type
            $DB_AZ_RSG_ALL = Get-AzResourceGroup | Select-Object * | Sort-Object Type
            Write-Host "        Suscription ID   :" $SUB.SubscriptionId -ForegroundColor Green
            Write-Host "        Suscription Name :" $SUB.Name -ForegroundColor Green
            #endregion selección de subscripción y recursos

            #region informacion de las subscripciones
            
            #region comprobaciones internas de suscripciones
            Remove-Variable SEC_AUT -ErrorAction SilentlyContinue
            Remove-Variable SEC_LOC -ErrorAction SilentlyContinue
            Remove-Variable SEC_PRI -ErrorAction SilentlyContinue
            Remove-Variable SEC_SET -ErrorAction SilentlyContinue
            $SEC_AUT = Get-AzSecurityAutoProvisioningSetting -ErrorVariable ERR_SEC -ErrorAction SilentlyContinue
            $SEC_LOC = Get-AzSecurityLocation -ErrorVariable ERR_SEC -ErrorAction SilentlyContinue
            $SEC_PRI = Get-AzSecurityPricing -ErrorVariable ERR_SEC -ErrorAction SilentlyContinue
            $SEC_SET = Get-AzSecuritySetting -ErrorVariable ERR_SEC -ErrorAction SilentlyContinue

            If($SEC_AUT.AutoProvision -eq "On"){
                $SEC_AUT = $true
            }
            else{
                $SEC_AUT = $false
            }

            if($null -ne $SEC_PRI){
                foreach ($PRI in $SEC_PRI) {
                    if($PRI.Name -eq "VirtualMachines"){
                        $SEC_VMS = $PRI.PricingTier
                    }
                    if($PRI.Name -eq "SqlServers"){
                        $SEC_SQL = $PRI.PricingTier
                    }
                    if($PRI.Name -eq "AppServices"){
                        $SEC_APP = $PRI.PricingTier
                    }
                    if($PRI.Name -eq "StorageAccounts"){
                        $SEC_STO = $PRI.PricingTier
                    }
                    if($PRI.Name -eq "SqlServerVirtualMachines"){
                        $SEC_SQV = $PRI.PricingTier
                    }
                    if($PRI.Name -eq "KubernetesService"){
                        $SEC_KUB = $PRI.PricingTier
                    }
                    if($PRI.Name -eq "ContainerRegistry"){
                        $SEC_CON = $PRI.PricingTier
                    }
                    if($PRI.Name -eq "KeyVaults"){
                        $SEC_KEY = $PRI.PricingTier
                    }
                }
            }
            else{
                $SEC_VMS = "Undefined"
                $SEC_SQL = "Undefined"
                $SEC_APP = "Undefined"
                $SEC_STO = "Undefined"
                $SEC_SQV = "Undefined"
                $SEC_KUB = "Undefined"
                $SEC_CON = "Undefined"
                $SEC_KEY = "Undefined"
            }

            if($null -ne $SEC_SET){
                foreach ($SET in $SEC_SET) {
                    if($SET.Name -eq "MCAS"){
                        $SEC_CAS = $SET.Enabled
                    }
                    if($SET.Name -eq "WDATP"){
                        $SEC_WDA = $SET.Enabled
                    }
                }
            }
            else{
                $SEC_CAS = $false
                $SEC_WDA = $false
            }

            if(!$SEC_LOC.Name){
                $SEC_LOC = "Undefined"
            }
            else{
                $SEC_LOC = $SEC_LOC.Name
            }
            

            if(!($DB_AZ_RES_ALL | Select-Object Location -Unique).Count){
                if(($DB_AZ_RES_ALL | Select-Object Location -Unique).Location){
                    $SUB_REG = 1
                }
                else{
                    $SUB_REG = 0
                }
            }
            else{
                $SUB_REG = ($DB_AZ_RES_ALL | Select-Object Location -Unique).Count
            }

            if(!$DB_AZ_RSG_ALL.Count){
                if(($DB_AZ_RSG_ALL | Select-Object ResourceGroupName -Unique).ResourceGroupName){
                    $REG_CNT = 1
                }
                else{
                    $REG_CNT = 0
                }
            }
            else{
                $REG_CNT = $DB_AZ_RSG_ALL.Count
            }
            #endregion comprobaciones internas de suscripciones

            Write-Host "    B. Cargando de informacion de subscripcion" -ForegroundColor Cyan
            $SUB_TNT = (Get-AzureADTenantDetail | Select-Object DisplayName).DisplayName
            Add-AzTableRow `
                -UpdateExisting `
                -Table $OUT_DB_TBL_SUB.CloudTable `
                -PartitionKey $SUB.TenantId `
                -RowKey $SUB.SubscriptionId `
                -Property @{
                    "Name" = $SUB.Name;
                    "State" = $SUB.State;
                    "Environment" = ($SUB.ExtendedProperties | ConvertTo-Json | ConvertFrom-Json).Environment;
                    "TenantDomain" = $COR_AZ_TNT_ALL.TenantDomain;
                    "TenantName" = $SUB_TNT;
                    "Regions" = $SUB_REG;
                    "ResourceGroup" = $REG_CNT;
                    "Resources" = ($DB_AZ_RES_ALL | Measure-Object).Count;
                    "ResourceProviders" = ($DB_AZ_RES_TYP | Measure-Object).Count;
                    "AzSecurityAutoProvisioning" = $SEC_AUT;
                    "AzSecurityLocation" = $SEC_LOC;
                    "AzSecurityVirtualMachines" = $SEC_VMS;
                    "AzSecuritySqlServers" = $SEC_SQL;
                    "AzSecurityAppServices" = $SEC_APP;
                    "AzSecurityStorageAccounts" = $SEC_STO;
                    "AzSecuritySqlServerVirtualMachines" = $SEC_SQV;
                    "AzSecurityKubernetesService" = $SEC_KUB;
                    "AzSecurityContainerRegistry" = $SEC_CON;
                    "AzSecurityKeyVaults" = $SEC_KEY;
                    "AzSecurityMCAS" = $SEC_CAS;
                    "AzSecurityWDATP" = $SEC_WDA;
                } | Out-Null
            Write-Host "        Se cargo la informacion de la subscripcion " $SUB.SubscriptionId "exitosamente" -ForegroundColor DarkGreen

            #endregion informacion de las subscripciones

            #region provisionamiento de tablas de acceso de recursos
            Write-Host "    C. Creacion de tablas para informacion de recursos" -ForegroundColor Cyan
            $DB_AZ_RES_TYP  = @()
            ($DB_AZ_RES_ALL | Select-Object Type -Unique) | ForEach-Object { $DB_AZ_RES_TYP += $_.Type.Replace("/",".").ToLower()}
            $DB_AZ_RES_TYP = $DB_AZ_RES_TYP | Select-Object -Unique

            foreach($RES in $DB_AZ_RES_TYP){
            
                $FOR_INT_00 = $RES.replace(".","")
                $FOR_INT_01 = Get-AzStorageTable -Context $OUT_TBL_CTX -Name $FOR_INT_00 -ErrorAction SilentlyContinue
                if(!$FOR_INT_01){
                    Start-Sleep -Seconds 5
                    $FOR_INT_01 = New-AzStorageTable -Context $OUT_TBL_CTX -Name $FOR_INT_00
                }

                $FOR_INT_00 = $null
                $FOR_INT_01 = $null

            }
            #region creacion de tabla para discos no atachados
            $FOR_INT_01 = Get-AzStorageTable -Context $OUT_TBL_CTX -Name microsoftcomputedisksu -ErrorAction SilentlyContinue
            if(!$FOR_INT_01){
                New-AzStorageTable -Context $OUT_TBL_CTX -Name microsoftcomputedisksu
            }
            #endregion creacion de tabla para discos no atachados

            Write-Host "        Se crearon " $DB_AZ_RES_TYP.Length "tablas de forma exitosa" -ForegroundColor DarkGreen

            #endregion provisionamiento de tablas de acceso de recursos
            
            #region informacion de las regiones empleadas
            
            Write-Host "    D. Cargando de informacion de regiones empleadas" -ForegroundColor Cyan
            $DB_AZ_RES_REG = $DB_AZ_RES_ALL | Select-Object Location -Unique
            
            foreach($REG in $DB_AZ_RES_REG){
                Add-AzTableRow `
                    -UpdateExisting `
                    -Table $OUT_DB_TBL_REG.CloudTable `
                    -PartitionKey $SUB.SubscriptionId `
                    -RowKey $REG.Location `
                    -Property @{
                        "ResourcesNumber" = ($DB_AZ_RES_ALL | Where-Object {$_.Location -eq $REG.Location} | Measure-Object).Count;
                        "TenantId" = $SUB.TenantId
                    } | Out-Null
            }
            if($DB_AZ_RES_REG.Length){
                Write-Host "        Se cargaron " $DB_AZ_RES_REG.Length " regiones exitosamente" -ForegroundColor DarkGreen
            }
            else{
                Write-Host "        Se cargaron 1 regiones exitosamente" -ForegroundColor DarkGreen
            }
            

            #endregion informacion de las regiones empleadas

            #region información de grupos de recursos
            
            Write-Host "    E. Cargando de informacion de grupo de recursos empleadas" -ForegroundColor Cyan
            
            foreach($GRP in $DB_AZ_RSG_ALL){
                Add-AzTableRow `
                    -UpdateExisting `
                    -Table $OUT_DB_TBL_RSG.CloudTable `
                    -PartitionKey $SUB.TenantId `
                    -RowKey $GRP.ResourceGroupName `
                    -Property @{
                        "Location" = $GRP.Location;
                        "ProvisioningState" = $GRP.ProvisioningState;
                        "ResourceId" = $GRP.ResourceId;
                        "ResourcesNumber" = ($DB_AZ_RES_ALL | Where-Object {$_.ResourceGroupName -eq $GRP.ResourceGroupName} | Measure-Object).Count;
                        "SubscriptionId" = $SUB.SubscriptionId 
                    } | Out-Null
            }
            Write-Host "        Se cargaron " $DB_AZ_RSG_ALL.Length " grupos de recursos exitosamente" -ForegroundColor DarkGreen

            #endregion información de grupos de recursos

            #region información general de recursos
            
            Write-Host "    F. Cargando de informacion general de recursos" -ForegroundColor Cyan
            $GBL_IN_FOR_CNT = 1
            foreach($RES in $DB_AZ_RES_ALL){
                $WR_BAR = ($RES.ResourceId.Substring($RES.ResourceId.IndexOf("providers")+10)).Replace("/",".").Replace(" ","_").Replace("#","_")
                If(!$RES.ParentResource){
                    $PAR_RES = "Undefined"
                }
                else{
                    $PAR_RES = $RES.ParentResource
                }
                            
                Add-AzTableRow `
                    -UpdateExisting `
                    -Table $OUT_DB_TBL_RES.CloudTable `
                    -PartitionKey $SUB.TenantId `
                    -RowKey $WR_BAR `
                    -Property @{
                        "Location" = $RES.Location;
                        "ResourceType" = $RES.ResourceType;
                        "ResourceCompany" = $RES.ResourceType.Substring(0,$RES.ResourceType.LastIndexOf("."));
                        "ResourceTypeMaster" = $RES.ResourceType.Substring(0,$RES.ResourceType.LastIndexOf("/"));
                        "ResourceTypeSubtype" = $RES.ResourceType.Substring($RES.ResourceType.LastIndexOf("/")+1);
                        "ResourceId" = $RES.ResourceId.Substring($RES.ResourceId.IndexOf("resourceGroups")+15);
                        "ResourceName" = $RES.ResourceId.Substring($RES.ResourceId.LastIndexOf("/")+1);
                        "ParentResource" = $PAR_RES;
                        "SubscriptionId" = $SUB.SubscriptionId;
                        "ResourceGroupName" = $RES.ResourceGroupName
                    } | Out-Null
                $GBL_IN_FOR_CNT++
            }
            if($DB_AZ_RES_ALL.Count){
                Write-Host "        Se cargaron " $DB_AZ_RES_ALL.Length " recursos exitosamente" -ForegroundColor DarkGreen
            }
            else{
                Write-Host "        Se cargaron 1 recursos exitosamente" -ForegroundColor DarkGreen
            }
            $GBL_IN_FOR_CNT = 1
            #endregion información general de recursos

            #region información recomendaciones de azure advisor
            
            Write-Host "    G. Cargando de informacion de recomendaciones de Azure Advisor" -ForegroundColor Cyan
            $DB_AZ_REC_ALL = Get-AzAdvisorRecommendation | Select-Object * | Sort-Object Category
            $GBL_IN_FOR_CNT = 1
            foreach($REC in $DB_AZ_REC_ALL){ 
                $WR_BAR = $REC.Name
                $IM_FLD = $REC.ImpactedField
                if(!$IM_FLD){
                    $IM_FLD = "Undefined"
                    $IM_PRO = "Undefined"
                    $IM_TYP = "Undefined"
                    $IM_SBT = "Undefined"

                }
                else{
                    $IM_PRO = $REC.ImpactedField.Substring(0,$REC.ImpactedField.IndexOf("."))
                    $IM_TYP = $REC.ImpactedField.Substring($REC.ImpactedField.IndexOf(".")+1,($REC.ImpactedField.Substring($REC.ImpactedField.IndexOf(".")+1).IndexOf("/")))
                    $IM_SBT = $REC.ImpactedField.Substring($REC.ImpactedField.IndexOf("/")+1)
                }

                Add-AzTableRow `
                    -UpdateExisting `
                    -Table $OUT_DB_TBL_REC.CloudTable `
                    -PartitionKey $SUB.TenantId `
                    -RowKey $WR_BAR `
                    -Property @{
                        "Problem" = $REC.ShortDescription.Problem;
                        "Solution" = $REC.ShortDescription.Solution;
                        "ImpactedValue" = $REC.ImpactedValue;
                        "ImpactedField" = $IM_FLD;
                        "ImpactedProvider" = $IM_PRO;
                        "ImpactedType" = $IM_TYP;
                        "ImpactedSubType" = $IM_SBT;
                        "Impact" = $REC.Impact;
                        "LastUpdated" = $REC.LastUpdated.DateTime;
                        "SubscriptionId" = $SUB.SubscriptionId;
                        "Category" = $REC.Category
                    } | Out-Null
                $GBL_IN_FOR_CNT++
            }

            if($DB_AZ_REC_ALL.Count){
                Write-Host "        Se cargaron " $DB_AZ_REC_ALL.Length " recomendaciones exitosamente" -ForegroundColor DarkGreen
            }
            else{
                Write-Host "        Se cargaron  1  recomendaciones exitosamente" -ForegroundColor DarkGreen
            }
            
            $GBL_IN_FOR_CNT = 1
            #endregion información recomendaciones de azure advisor

            #region información de informacion de usuarios administrativos de Azure
                
            Write-Host "    H. Cargado de informacion de usuarios administrativos de Azure" -ForegroundColor Cyan
            $DB_AZ_PER_ALL = Get-AzRoleAssignment | Select-Object * | Sort-Object Scope -Descending
            $GBL_IN_FOR_CNT = 1
            foreach($USR in $DB_AZ_PER_ALL){
                $WR_BAR = $USR.DisplayName
                $FD_SCP = $USR.Scope
                $FD_SIG = $USR.SignInName
                $FD_ROW = $USR.RoleAssignmentId.Substring($USR.RoleAssignmentId.LastIndexOf("/")+1)
                if($USR.ObjectType -eq "User"){
                    $FS_TYP = Get-AzureADUser -ObjectId $USR.ObjectId | Select-Object *
                    if($FS_TYP.UserType){
                        $FS_TYP =  $FS_TYP.UserType
                    }
                    elseif($FS_TYP.ImmutableId){
                        $FS_TYP = "Member"
                    }
                    else{
                        $FS_TYP = "Undefined"
                    }
                }
                elseif ($USR.ObjectType -eq "ServicePrincipal") {
                    $FS_TYP = (Get-AzureADServicePrincipal -ObjectId $USR.ObjectId | Select-Object ServicePrincipalType).ServicePrincipalType
                }
                else {
                    $FS_TYP = $USR.ObjectType
                }
                
                if($FD_SCP -like "*managementGroups*" ){
                    $FD_SCP = "Management Group"
                }
                elseif($FD_SCP -like "*providers*" ){
                    $FD_SCP = "Resource"
                }
                elseif ($FD_SCP -like "*resourcegroups*") {
                    $FD_SCP = "Resource Group"
                }
                elseif ($FD_SCP -like "*subscriptions*") {
                    $FD_SCP = "Subscription"
                }
                else{
                    $FD_SCP = "Root"
                }

                if(!$FD_SIG){
                    $FD_SIG = "Undefined"
                }

                Add-AzTableRow `
                    -UpdateExisting `
                    -Table $OUT_DB_TBL_PER.CloudTable `
                    -PartitionKey $SUB.TenantId `
                    -RowKey $FD_ROW `
                    -Property @{
                        "RoleAssignmentId" = $USR.RoleAssignmentId;
                        "Scope" = $USR.Scope;
                        "ScopeLevel" = $FD_SCP;
                        "DisplayName" = $USR.DisplayName;
                        "SignInName" = $FD_SIG;
                        "RoleDefinitionName" = $USR.RoleDefinitionName;
                        "RoleDefinitionId" = $USR.RoleDefinitionId;
                        "CanDelegate" = $USR.CanDelegate;
                        "ObjectType" = $USR.ObjectType;
                        "UserType" = $FS_TYP;
                        "SubscriptionId" = $SUB.SubscriptionId
                    } | Out-Null
                $GBL_IN_FOR_CNT++
                
            }
            Write-Host "        Se cargaron " $DB_AZ_PER_ALL.Length " usuarios administrativos exitosamente" -ForegroundColor DarkGreen
            $GBL_IN_FOR_CNT = 1
            #endregion información de informacion de usuarios administrativos de Azure

            #region informacion de Storages Accounts
                
            Write-Host "    I. Cargando de informacion de cuentas de almacenamiento" -ForegroundColor Cyan
            $DB_AZ_STO_ALL = $DB_AZ_RES_ALL | Where-Object {$_.ResourceType -eq 'Microsoft.Storage/storageAccounts'} | Select-Object *
            if($DB_AZ_STO_ALL){
                $OUT_DB_TBL_STO = Get-AzStorageTable -Context $OUT_TBL_CTX -Name ((($DB_AZ_STO_ALL | Select-Object ResourceType -Unique).ResourceType).ToLower().replace(".","").replace("/",""))
                $GBL_IN_FOR_CNT = 1
                foreach($STO in $DB_AZ_STO_ALL){
                    $STO_INF = Get-AzStorageAccount -ResourceGroupName $STO.ResourceGroupName -Name $STO.Name
                    $WR_BAR = $STO_INF.StorageAccountName
                    
                    #region comprobaciones internas de Storages Accounts
                    if(!$STO_INF.CustomDomain){
                        $CST_DMN = "-"
                    }
                    else{
                        $CST_DMN = $STO_INF.CustomDomain
                    }
                    if(!$STO_INF.LargeFileSharesState){
                        $SHR_LRG = "-"
                    }
                    else{
                        $SHR_LRG = $STO_INF.LargeFileSharesState
                    }
                    If(!$STO_INF.NetworkRuleSet.IpRules){
                        $RL_IPS = "None"
                        $DF_IPS = "None"
                    }
                    else{
                        $RL_IPS = ($STO_INF.NetworkRuleSet.IpRules | Measure-Object).Count
                        $DF_IPS = ($STO_INF.NetworkRuleSet.IpRules | Select-Object IpAddressOrRange).IpAddressOrRange -join ";"
                    }
                    If(!$STO_INF.NetworkRuleSet.VirtualNetworkRules){
                        $RL_VNT = "None"
                        $DF_VNT = "None"
                    }
                    else{
                        $RL_VNT = ($STO_INF.NetworkRuleSet.VirtualNetworkRules | Measure-Object).Count
                        $DF_VNT = ($STO_INF.NetworkRuleSet.VirtualNetworkRules.VirtualNetworkResourceId | ForEach-Object { $_.Substring($_.LastIndexOf("resourceGroups/")+15).Replace("/providers/Microsoft.Network/virtualNetworks","").Replace("/subnets","")} ) -join ";"
                    }
                    If(!$STO_INF.AccessTier){
                        $ACC_TIR = "-"
                    }
                    else{
                        $ACC_TIR = $STO_INF.AccessTier.ToString()
                    }
                    If(!$STO_INF.SecondaryLocation){
                        $SEC_LOC = "-"
                    }
                    else{
                        $SEC_LOC = $STO_INF.SecondaryLocation
                    }
                    If($SEC_LOC -eq "-"){
                        $SEC_STS = "-"
                    }
                    else{
                        $SEC_STS = $STO_INF.StatusOfSecondary.ToString()
                    }
                    #endregion comprobaciones internas de Storages Accounts
                    Add-AzTableRow `
                        -UpdateExisting `
                        -Table $OUT_DB_TBL_STO.CloudTable `
                        -PartitionKey $SUB.SubscriptionId `
                        -RowKey $STO_INF.StorageAccountName `
                        -Property @{
                            "ResourceGroupName" = $STO_INF.ResourceGroupName;
                            "Id" = $STO_INF.Id;
                            "Location" = $STO_INF.Location;
                            "SkuName" = $STO_INF.Sku.Name.ToString();
                            "SkuTier" = $STO_INF.Sku.Tier.ToString();
                            "Kind" = $STO_INF.Kind.ToString();
                            "AccessTier" = $ACC_TIR;
                            "CreationTime" = $STO_INF.CreationTime;
                            "CustomDomain" = $CST_DMN;
                            "PrimaryLocation" = $STO_INF.PrimaryLocation.ToString();
                            "SecondaryLocation" = $SEC_LOC;
                            "StatusOfPrimary" = $STO_INF.StatusOfPrimary.ToString();
                            "StatusOfSecondary" = $SEC_STS;
                            "ProvisioningState" = $STO_INF.ProvisioningState.ToString();
                            "EnableHttpsTrafficOnly" = $STO_INF.EnableHttpsTrafficOnly;
                            "LargeFileSharesState" = $SHR_LRG;
                            "NetworkRuleSetBypass" = $STO_INF.NetworkRuleSet.Bypass.ToString();
                            "NetworkRuleSetDefaultAction" = $STO_INF.NetworkRuleSet.DefaultAction.ToString();
                            "NetworkRuleSetIpRules" = $RL_IPS;
                            "NetworkRuleSetIpRulesDetails" = $DF_IPS;
                            "NetworkRuleSetVirtualNetworkRules" = $RL_VNT;
                            "NetworkRuleSetVirtualNetworkRulesDetails" = $DF_VNT;
                            "Encryption" = $STO_INF.Encryption.KeySource;
                            "TenantId" = $SUB.TenantId
                        } | Out-Null
                    $GBL_IN_FOR_CNT++

                }
                if($DB_AZ_STO_ALL.Count){
                    Write-Host "        Se cargaron " $DB_AZ_STO_ALL.Length " cuentas de almacenamiento exitosamente" -ForegroundColor DarkGreen
                }
                else{
                    Write-Host "        Se cargaron  1  cuentas de almacenamiento exitosamente" -ForegroundColor DarkGreen
                }

                $GBL_IN_FOR_CNT = 1
            }
            else{
                Write-Host "        No se tienen cuentas de almacenamiento que revisar" -ForegroundColor DarkGreen
            }
            
            #endregion informacion de Storages Accounts

            #region informacion de Virtual Machines
        
            Write-Host "    J. Cargando de informacion de maquinas virtuales" -ForegroundColor Cyan
            $DB_AZ_CMP_ALL = $DB_AZ_RES_ALL | Where-Object {$_.ResourceType -eq 'Microsoft.Compute/virtualMachines'} | Select-Object *
            if($DB_AZ_CMP_ALL){
                $OUT_DB_TBL_CMP = Get-AzStorageTable -Context $OUT_TBL_CTX -Name ((($DB_AZ_CMP_ALL | Select-Object ResourceType -Unique).ResourceType).ToLower().replace(".","").replace("/",""))
                $GBL_IN_FOR_CNT = 1
                foreach($CMP in $DB_AZ_CMP_ALL){
                    $CMP_INF = Get-AzVM -ResourceGroupName $CMP.ResourceGroupName -Name $CMP.Name
                    $WR_BAR = $CMP_INF.Name

                    #region comprobaciones internas de virtual machines
                    if($null -ne $CMP_INF.OSProfile.WindowsConfiguration){
                        $SO_CONFIG = "Windows"
                        if($CMP_INF.OSProfile.WindowsConfiguration.ProvisionVMAgent){
                            $AGN_PRO = "Installed"
                        }
                        else{
                            $AGN_PRO = "Missing"
                        }
                        $AUT_UPD = $CMP_INF.OSProfile.WindowsConfiguration.EnableAutomaticUpdates
                        $PSW_AUT = "-"
                        $SSH_PAT = "-"
                    }
                    else{
                        $SO_CONFIG = "Linux"
                        if($CMP_INF.OSProfile.LinuxConfiguration.ProvisionVMAgent){
                            $AGN_PRO = "Installed"
                        }
                        else{
                            $AGN_PRO = "Missing"
                        }                 
                        $PSW_AUT = $CMP_INF.OSProfile.LinuxConfiguration.DisablePasswordAuthentication
                        if($CMP_INF.OSProfile.LinuxConfiguration.Ssh){
                            $SSH_PAT = ($CMP_INF.OSProfile.LinuxConfiguration.Ssh.PublicKeys | Select-Object Path).Path -Join ";"
                        }
                        else{
                            $SSH_PAT = "-"
                        }
                        $AUT_UPD = "-"
                    }
                    If($null -ne $CMP_INF.OSProfile.AllowExtensionOperations){
                        if($CMP_INF.OSProfile.AllowExtensionOperations -eq $true){
                            $ALL_EXT = "Allowed"
                        }
                        else{
                            $ALL_EXT = "Not Allowed"
                        }
                    }
                    else{
                        $ALL_EXT = "Undefined"  
                    }
                    if($null -ne $CMP_INF.OSProfile.RequireGuestProvisionSignal){
                        if($CMP_INF.OSProfile.RequireGuestProvisionSignal -eq $true){
                            $GST_PRO = "Allowed"
                        }
                        else{
                            $GST_PRO = "Not Allowed"
                        }
                    }
                    else{
                        $GST_PRO = "Undefined"
                    }
                    if($null -ne $CMP_INF.DiagnosticsProfile.BootDiagnostics.Enabled){
                        $BOT_ENA = $CMP_INF.DiagnosticsProfile.BootDiagnostics.Enabled.ToString()
                        if($CMP_INF.DiagnosticsProfile.BootDiagnostics.StorageUri){
                            $BOT_STO = $CMP_INF.DiagnosticsProfile.BootDiagnostics.StorageUri
                        }
                        else{
                            $BOT_STO = "Undefined"
                        }
                    }
                    else{
                        $BOT_ENA = "Undefined"
                        $BOT_STO = "Undefined"
                    }
                    if($null -ne $CMP_INF.StorageProfile.OsDisk.ManagedDisk){
                        $OS_MGM = "Managed"
                        $OS_PAT = $CMP_INF.StorageProfile.OsDisk.ManagedDisk.Id
                        $OS_STO = "Managed"
                        $OS_VHD = "Managed"
                    }
                    else{
                        $OS_MGM = "Unmanaged"
                        $OS_PAT = $CMP_INF.StorageProfile.OsDisk.Vhd.Uri
                        $IN_FIR = $OS_PAT.Substring($OS_PAT.IndexOf("//")+2)
                        $OS_STO = $IN_FIR.Substring(0,$IN_FIR.IndexOf("."))
                        $OS_VHD = $OS_PAT.Substring($OS_PAT.LastIndexOf("/")+1)
                    }
                    
                    #endregion comprobaciones internas de virtual machines
                    Add-AzTableRow `
                        -UpdateExisting `
                        -Table $OUT_DB_TBL_CMP.CloudTable `
                        -PartitionKey $SUB.SubscriptionId `
                        -RowKey $CMP_INF.VmId `
                        -Property @{
                            "TenantId" = $SUB.TenantId;
                            "ResourceGroupName" = $CMP_INF.ResourceGroupName;
                            "Id" = $CMP_INF.Id;
                            "Name" = $CMP_INF.Name;
                            "Type" = $CMP_INF.Type;
                            "Location" = $CMP_INF.Location;
                            "BootDiagnostics" = $BOT_ENA;
                            "BootDiagnosticsStorage" = $BOT_STO;
                            "VmSize" = $CMP_INF.HardwareProfile.VmSize;
                            "ComputerName" = $CMP_INF.OSProfile.ComputerName;
                            "AdminUsername" = $CMP_INF.OSProfile.AdminUsername;
                            "OperatingSystem" = $SO_CONFIG;
                            "OperatingSystemPublisher" = $CMP_INF.StorageProfile.ImageReference.Publisher;
                            "OperatingSystemOffer" = $CMP_INF.StorageProfile.ImageReference.Offer;
                            "OperatingSystemSku" = $CMP_INF.StorageProfile.ImageReference.Sku;
                            "OperatingSystemVersion" = $CMP_INF.StorageProfile.ImageReference.Version;
                            "OperatingSystemExactVersion" = $CMP_INF.StorageProfile.ImageReference.ExactVersion;
                            "ProvisionVMAgent" = $AGN_PRO;
                            "LinuxDisablePasswordAuthentication" = $PSW_AUT;
                            "LinuxSSHPaths" = $SSH_PAT;
                            "WindowsEnableAutomaticUpdates" = $AUT_UPD;
                            "ProvisioningState" = $CMP_INF.ProvisioningState;
                            "AllowExtensionOperations" = $ALL_EXT;
                            "RequireGuestProvisionSignal" = $GST_PRO;
                            "ManagedDisk" = $OS_MGM;
                            "OperatingSystemDisk" = $OS_PAT;
                            "OperatingSystemStorage" = $OS_STO;
                            "OperatingSystemVHD" = $OS_VHD;
                            "NumberTags" = ($CMP_INF.Tags.Keys | Measure-Object).Count
                            
                        } | Out-Null
                    $GBL_IN_FOR_CNT++

                }
                if($DB_AZ_CMP_ALL.Count){
                    Write-Host "        Se cargaron " $DB_AZ_CMP_ALL.Length " maquinas virtuales exitosamente" -ForegroundColor DarkGreen
                }
                else{
                    Write-Host "        Se cargaron 1 maquina virtual exitosamente" -ForegroundColor DarkGreen
                }
                $GBL_IN_FOR_CNT = 1
            }
            else{
                Write-Host "        No se tienen maquinas virtuales que revisar" -ForegroundColor DarkGreen    
            }
            
            #endregion informacion de Virtual Machines

            #region informacion de Azure Disks
        
            Write-Host "    K. Cargando de informacion de azure disks" -ForegroundColor Cyan
            $DB_AZ_DSK_ALL = $DB_AZ_RES_ALL | Where-Object {$_.ResourceType -eq 'Microsoft.Compute/disks'} | Select-Object *
            if($DB_AZ_DSK_ALL){
                $OUT_DB_TBL_DSK = Get-AzStorageTable -Context $OUT_TBL_CTX -Name ((($DB_AZ_DSK_ALL | Select-Object ResourceType -Unique).ResourceType).ToLower().replace(".","").replace("/",""))
                $OUT_DB_TBL_DSU = Get-AzStorageTable -Context $OUT_TBL_CTX -Name (((($DB_AZ_DSK_ALL | Select-Object ResourceType -Unique).ResourceType).ToLower().replace(".","").replace("/","")) + "u")
                $GBL_IN_FOR_CNT = 1
                foreach($DSK in $DB_AZ_DSK_ALL){
                    $DSK_INF = Get-AzDisk -ResourceGroupName $DSK.ResourceGroupName -Name $DSK.Name -ErrorAction SilentlyContinue
                    $WR_BAR = $DSK_INF.Name

                    if($DSK_INF){
                        #region comprobaciones internas de azure disks
                        if($null -ne $DSK_INF.DiskIOPSReadOnly){
                            $RO_IOP = $DSK_INF.DiskIOPSReadOnly
                        }
                        else{
                            $RO_IOP = "Undefined"
                        }
                        if($null -ne $DSK_INF.DiskMBpsReadOnly){
                            $RO_MBP = $DSK_INF.DiskMBpsReadOnly
                        }
                        else{
                            $RO_MBP = "Undefined"
                        }
                        if($null -ne $DSK_INF.ManagedBy){
                            $BY_MGM = $DSK_INF.ManagedBy
                        }
                        else{
                            $BY_MGM = "Unattached"
                        }
                        if($null -ne $DSK_INF.OsType){
                            $TP_DSK = $DSK_INF.OsType.ToString()
                            $TP_DAT = "OperatingSystem"
                        }
                        else{
                            $TP_DSK = "None"
                            $TP_DAT = "Data"
                        }
                        if($null -ne $DSK_INF.HyperVGeneration){
                            $HV_GEN = $DSK_INF.HyperVGeneration
                        }
                        else{
                            $HV_GEN = "Undefined"
                        }
                        switch ($DSK_INF.CreationData.CreateOption) {
                            FromImage {  
                                $CR_OPT = $DSK_INF.CreationData.CreateOption
                                $CR_STO = "-"
                                $CR_IMG = $DSK_INF.CreationData.ImageReference.Id
                                $CR_REF = "-"
                                $CR_SRC_ID = "-"
                                $CR_SRC_RS = "-"
                                $CR_SRC_UN = "-"
                                $CR_UPL = "-"
                            }
                            Copy {  
                                $CR_OPT = $DSK_INF.CreationData.CreateOption
                                $CR_STO = "-"
                                $CR_IMG = "-"
                                $CR_REF = "-"
                                $CR_SRC_ID = "-"
                                $CR_SRC_RS = $DSK_INF.CreationData.SourceResourceId
                                $CR_SRC_UN = $DSK_INF.CreationData.SourceUniqueId
                                $CR_UPL = "-"
                            }
                            Empty {  
                                $CR_OPT = $DSK_INF.CreationData.CreateOption
                                $CR_STO = "-"
                                $CR_IMG = "-"
                                $CR_REF = "-"
                                $CR_SRC_ID = "-"
                                $CR_SRC_RS = "-"
                                $CR_SRC_UN = "-"
                                $CR_UPL = "-"
                            }
                            Default {
                                $CR_OPT = "-"
                                $CR_STO = "-"
                                $CR_IMG = "-"
                                $CR_REF = "-"
                                $CR_SRC_ID = "-"
                                $CR_SRC_RS = "-"
                                $CR_SRC_UN = "-"
                                $CR_UPL = "-"
                            }
                        }
                        #endregion comprobaciones internas de azure disks
                        if($BY_MGM -eq "Unattached"){
                            Add-AzTableRow `
                            -UpdateExisting `
                            -Table $OUT_DB_TBL_DSU.CloudTable `
                            -PartitionKey $SUB.SubscriptionId `
                            -RowKey $DSK_INF.Name `
                            -Property @{
                                "TenantId" = $SUB.TenantId;
                                "ResourceGroupName" = $DSK_INF.ResourceGroupName;
                                "ManagedBy" = $BY_MGM;
                                "SkuName" = $DSK_INF.Sku.Name;
                                "SkuTier" = $DSK_INF.sku.Tier;
                                "TimeCreated" = $DSK_INF.TimeCreated;
                                "OsType" = $TP_DSK;
                                "DiskType" = $TP_DAT;
                                "HyperVGeneration" = $HV_GEN;
                                "CreateOption" = $CR_OPT;
                                "CreateStorageAccountId" = $CR_STO;
                                "CreateImageReference" = $CR_IMG;
                                "CreateGalleryImageReference" = $CR_REF;
                                "CreateSourceUri" = $CR_SRC_ID;
                                "CreateSourceResourceId" = $CR_SRC_RS;
                                "CreateSourceUniqueId" = $CR_SRC_UN;
                                "CreateUploadSizeBytes" = $CR_UPL;
                                "DiskSizeGB" = $DSK_INF.DiskSizeGB;
                                "DiskSizeMB" = ($DSK_INF.DiskSizeBytes / 1MB);
                                "DiskSizeBytes" = $DSK_INF.DiskSizeBytes;
                                "UniqueId" = $DSK_INF.UniqueId;
                                "ProvisioningState" = $DSK_INF.ProvisioningState;
                                "DiskIOPSReadWrite" = $DSK_INF.DiskIOPSReadWrite;
                                "DiskMBpsReadWrite" = $DSK_INF.DiskMBpsReadWrite;
                                "DiskIOPSReadOnly" = $RO_IOP;
                                "DiskMBpsReadOnly" = $RO_MBP;
                                "DiskState" = $DSK_INF.DiskState;
                                "Encryption" = $DSK_INF.Encryption.Type;
                                "Id" = $DSK_INF.Id;
                                "Name" = $DSK_INF.Name;
                                "Type" = $DSK_INF.Type;
                                "Location" = $DSK_INF.Location;
                                "Tags" = ($DSK_INF.Tags.Keys | Measure-Object).Count
                                
                            } | Out-Null
                        }
                        else{
                            Add-AzTableRow `
                            -UpdateExisting `
                            -Table $OUT_DB_TBL_DSK.CloudTable `
                            -PartitionKey $SUB.SubscriptionId `
                            -RowKey $DSK_INF.Name `
                            -Property @{
                                "TenantId" = $SUB.TenantId;
                                "ResourceGroupName" = $DSK_INF.ResourceGroupName;
                                "ManagedBy" = $BY_MGM;
                                "SkuName" = $DSK_INF.Sku.Name;
                                "SkuTier" = $DSK_INF.sku.Tier;
                                "TimeCreated" = $DSK_INF.TimeCreated;
                                "OsType" = $TP_DSK;
                                "DiskType" = $TP_DAT;
                                "HyperVGeneration" = $HV_GEN;
                                "CreateOption" = $CR_OPT;
                                "CreateStorageAccountId" = $CR_STO;
                                "CreateImageReference" = $CR_IMG;
                                "CreateGalleryImageReference" = $CR_REF;
                                "CreateSourceUri" = $CR_SRC_ID;
                                "CreateSourceResourceId" = $CR_SRC_RS;
                                "CreateSourceUniqueId" = $CR_SRC_UN;
                                "CreateUploadSizeBytes" = $CR_UPL;
                                "DiskSizeGB" = $DSK_INF.DiskSizeGB;
                                "DiskSizeMB" = ($DSK_INF.DiskSizeBytes / 1MB);
                                "DiskSizeBytes" = $DSK_INF.DiskSizeBytes;
                                "UniqueId" = $DSK_INF.UniqueId;
                                "ProvisioningState" = $DSK_INF.ProvisioningState;
                                "DiskIOPSReadWrite" = $DSK_INF.DiskIOPSReadWrite;
                                "DiskMBpsReadWrite" = $DSK_INF.DiskMBpsReadWrite;
                                "DiskIOPSReadOnly" = $RO_IOP;
                                "DiskMBpsReadOnly" = $RO_MBP;
                                "DiskState" = $DSK_INF.DiskState;
                                "Encryption" = $DSK_INF.Encryption.Type;
                                "Id" = $DSK_INF.Id;
                                "Name" = $DSK_INF.Name;
                                "Type" = $DSK_INF.Type;
                                "Location" = $DSK_INF.Location;
                                "Tags" = ($DSK_INF.Tags.Keys | Measure-Object).Count
                                
                            } | Out-Null
                        }
                        
                        $GBL_IN_FOR_CNT++
                    }
                }
                if($DB_AZ_DSK_ALL.Count){
                    Write-Host "        Se cargaron " $DB_AZ_DSK_ALL.Length " discos exitosamente" -ForegroundColor DarkGreen
                }
                else{
                    Write-Host "        Se cargaron 1 disco exitosamente" -ForegroundColor DarkGreen
                }
                
                $GBL_IN_FOR_CNT = 1
            }
            else{
                Write-Host "        No se tienen discos que revisar" -ForegroundColor DarkGreen
            }
            
            #endregion informacion de Azure Disks

            #region informacion de  Azure SQL Server
        
            Write-Host "    L. Cargando de informacion de Azure SQL Server" -ForegroundColor Cyan
            $DB_AZ_SQLSRV_ALL = $DB_AZ_RES_ALL | Where-Object {$_.ResourceType -eq 'Microsoft.Sql/servers'} | Select-Object *
            if($DB_AZ_SQLSRV_ALL){
                $OUT_DB_TBL_SQLSRV = Get-AzStorageTable -Context $OUT_TBL_CTX -Name ((($DB_AZ_SQLSRV_ALL | Select-Object ResourceType -Unique).ResourceType).ToLower().replace(".","").replace("/",""))
                $GBL_IN_FOR_CNT = 1
                foreach($SQLSRV in $DB_AZ_SQLSRV_ALL){
                    $SQLSRV_INF = Get-AzSqlServer -ResourceGroupName $SQLSRV.ResourceGroupName -Name $SQLSRV.Name
                    $SQLSRV_AZA = Get-AzSqlServerActiveDirectoryAdministrator -ServerName $SQLSRV_INF.ServerName -ResourceGroupName $SQLSRV_INF.ResourceGroupName
                    $SQLSRV_SEC = Get-AzSqlServerAdvancedDataSecurityPolicy -ServerName $SQLSRV_INF.ServerName -ResourceGroupName $SQLSRV_INF.ResourceGroupName
                    $WR_BAR = $SQLSRV_INF.ServerName

                    #region comprobaciones internas de azure sql server
                    if($null -ne $SQLSRV_INF.Identity){
                        $IDN_PRI = $SQLSRV_INF.Identity.PrincipalId.Guid;
                        $IDN_TYP = $SQLSRV_INF.Identity.Type;
                        $IDN_TNT = $SQLSRV_INF.Identity.TenantId.Guid;
                    }
                    else{
                        $IDN_PRI = "Undefined"
                        $IDN_TYP = "Undefined"
                        $IDN_TNT = "Undefined"
                    }
                    if($null -ne $SQLSRV_INF.PublicNetworkAccess){
                        $PUB_ACC = $SQLSRV_INF.PublicNetworkAccess
                    }
                    else{
                        $PUB_ACC = "Undefined"
                    }
                    if($null -ne $SQLSRV_INF.MinimalTlsVersion){
                        $TLS_VER = $SQLSRV_INF.MinimalTlsVersion
                    }
                    else{
                        $TLS_VER = "Undefined"
                    }
                    if($null -ne $SQLSRV_AZA){
                        if($null -ne $SQLSRV_AZA.DisplayName){
                            $ADM_DSP = $SQLSRV_AZA.DisplayName
                        }
                        else{
                            $ADM_DSP = "Undefined"
                        }
                        if($null -ne $SQLSRV_AZA.ObjectId){
                            $ADM_OBJ = $SQLSRV_AZA.ObjectId
                        }
                        else{
                            $ADM_OBJ = "Undefined"
                        }
                        if($null -ne $SQLSRV_AZA.IsAzureADOnlyAuthentication){
                            $ADM_AUT = $SQLSRV_AZA.IsAzureADOnlyAuthentication
                        }
                        else{
                            $ADM_AUT = "Undefined"
                        }
                    }
                    else{
                        $ADM_DSP = "Undefined"
                        $ADM_OBJ = "Undefined"
                        $ADM_AUT = "Undefined"
                    }
                    #endregion comprobaciones internas de azure sql server
                    Add-AzTableRow `
                    -UpdateExisting `
                    -Table $OUT_DB_TBL_SQLSRV.CloudTable `
                    -PartitionKey $SUB.SubscriptionId `
                    -RowKey $SQLSRV_INF.ServerName `
                    -Property @{
                        "TenantId" = $SUB.TenantId;
                        "ResourceGroupName" = $SQLSRV_INF.ResourceGroupName;
                        "Location" = $SQLSRV_INF.Location;
                        "SqlAdministratorLogin" = $SQLSRV_INF.SqlAdministratorLogin;
                        "ServerVersion" = $SQLSRV_INF.ServerVersion;
                        "Tags" = ($SQLSRV_INF.Tags.Keys | Measure-Object).Count;
                        "IdentityPrincipalId" = $IDN_PRI;
                        "IdentityType" = $IDN_TYP;
                        "IdentityTenantId" = $IDN_TNT;
                        "FullyQualifiedDomainName" = $SQLSRV_INF.FullyQualifiedDomainName;
                        "ResourceId" = $SQLSRV_INF.ResourceId;
                        "PublicNetworkAccess" = $PUB_ACC;
                        "MinimalTlsVersion" = $TLS_VER;
                        "AzADAdministrator" = $ADM_DSP;
                        "AzADAdministratorObjectID" = $ADM_OBJ;
                        "AzADOnlyAuthentication" = $ADM_AUT;
                        "AdvancedSecurity" = $SQLSRV_SEC.IsEnabled;
                    } | Out-Null
                    $GBL_IN_FOR_CNT++
                }
                if($DB_AZ_SQLSRV_ALL.Count){
                    Write-Host "        Se cargaron " $DB_AZ_SQLSRV_ALL.Length " Azure SQL Server exitosamente" -ForegroundColor DarkGreen
                }
                else{
                    Write-Host "        Se cargaron 1 Azure SQL Server exitosamente" -ForegroundColor DarkGreen
                }
                
                $GBL_IN_FOR_CNT = 1
            }
            else{
                Write-Host "        No se tienen Azure SQL Server que revisar" -ForegroundColor DarkGreen
            }
            
            #endregion informacion de  Azure SQL Server
        
            #region informacion de  Azure SQL Database

            Write-Host "    L. Cargando de informacion de Azure SQL Database" -ForegroundColor Cyan
            $DB_AZ_SQLDB_ALL = $DB_AZ_RES_ALL | Where-Object {$_.ResourceType -eq 'Microsoft.Sql/servers/databases'} | Select-Object *
            if($DB_AZ_SQLDB_ALL){
                $OUT_DB_TBL_SQLDB = Get-AzStorageTable -Context $OUT_TBL_CTX -Name ((($DB_AZ_SQLDB_ALL | Select-Object ResourceType -Unique).ResourceType).ToLower().replace(".","").replace("/",""))
                $GBL_IN_FOR_CNT = 1
                foreach($SQLDB in $DB_AZ_SQLDB_ALL){
                    $SQLDB_INF = Get-AzSqlDatabase -DatabaseName ($SQLDB.Name.Substring(($SQLDB.Name.ToString()).IndexOf("/")+1)) -ServerName ($SQLDB.ParentResource.Substring(($SQLDB.ParentResource.ToString()).IndexOf("/")+1)) -ResourceGroupName $SQLDB.ResourceGroupName
                    $WR_BAR = $SQLDB_INF.DatabaseName
                    
                    #region comprobaciones internas de Azure SQL Database
                    if($null -ne $SQLDB_INF.ZoneRedundant){
                        $DB_ZNA = $SQLDB_INF.ZoneRedundant
                    }
                    else{
                        $DB_ZNA = "Undefined"
                    }
                    if($null -ne $SQLDB_INF.EarliestRestoreDate){
                        $DB_RST = $SQLDB_INF.EarliestRestoreDate
                    }
                    else{
                        $DB_RST = "Undefined"
                    }
                    #endregion comprobaciones internas de Azure SQL Database
                    Add-AzTableRow `
                    -UpdateExisting `
                    -Table $OUT_DB_TBL_SQLDB.CloudTable `
                    -PartitionKey $SUB.SubscriptionId `
                    -RowKey $SQLDB_INF.DatabaseId `
                    -Property @{
                        "TenantId" = $SUB.TenantId;
                        "ResourceGroupName" = $SQLDB_INF.ResourceGroupName;
                        "ServerName" = $SQLDB_INF.ServerName;
                        "ServerFQDN" = ($SQLDB_INF.ServerName + ".database.windows.net");
                        "DatabaseName" = $SQLDB_INF.DatabaseName;
                        "Location" = $SQLDB_INF.Location;
                        "Edition" = $SQLDB_INF.Edition;
                        "CollationName" = $SQLDB_INF.CollationName;
                        "MaxSizeBytes" = $SQLDB_INF.MaxSizeBytes;
                        "Status" = $SQLDB_INF.Status;
                        "CreationDate" = $SQLDB_INF.CreationDate;
                        "CurrentServiceObjectiveId" = $SQLDB_INF.CurrentServiceObjectiveId;
                        "CurrentServiceObjectiveName" = $SQLDB_INF.CurrentServiceObjectiveName;
                        "RequestedServiceObjectiveName" = $SQLDB_INF.RequestedServiceObjectiveName;
                        "EarliestRestoreDate" = $DB_RST;
                        "Tags" = ($SQLDB_INF.Tags.Keys | Measure-Object).Count;
                        "ResourceId" = $SQLDB_INF.ResourceId;
                        "ReadScale" = $SQLDB_INF.ReadScale.ToString();
                        "ZoneRedundant" = $DB_ZNA;
                        "Capacity" = $SQLDB_INF.Capacity;
                        "SkuName" = $SQLDB_INF.SkuName;
                        "ReadReplicaCount" = $SQLDB_INF.ReadReplicaCount
                    } | Out-Null
                    $GBL_IN_FOR_CNT++
                        if( $null -ne $SQLDB_INF.CatalogCollation -or
                            $null -ne $SQLDB_INF.RequestedServiceObjectiveId -or
                            $null -ne $SQLDB_INF.ElasticPoolName -or
                            $null -ne $SQLDB_INF.CreateMode -or
                            $null -ne $SQLDB_INF.Family -or
                            $null -ne $SQLDB_INF.LicenseType -or
                            $null -ne $SQLDB_INF.AutoPauseDelayInMinutes -or
                            $null -ne $SQLDB_INF.MinimumCapacity){
                            pause
                        }
                }
                if($DB_AZ_SQLDB_ALL.Count){
                    Write-Host "        Se cargaron " $DB_AZ_SQLDB_ALL.Length " Azure SQL Database exitosamente" -ForegroundColor DarkGreen
                }
                else{
                    Write-Host "        Se cargaron 1 Azure SQL Database exitosamente" -ForegroundColor DarkGreen
                }
                
                $GBL_IN_FOR_CNT = 1
            }
            else{
                Write-Host "        No se tienen Azure SQL Database que revisar" -ForegroundColor DarkGreen
            }
            
            #endregion informacion de  Azure SQL Database
        }
        $GBL_IN_SUB_CNT++
    }
    ################################################################################################
    #endregion                              Process Section
    ################################################################################################

    ################################################################################################
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
                    "value" = $SUB.TenantId
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
    ################################################################################################
}


