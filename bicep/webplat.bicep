// ============================================================================
// azure-security-operations-platform / bicep/webplat.bicep
//
// Orchestrator that deploys a secure, administrator-manageable web hosting
// platform: a private AKS cluster + private ACR + Application Gateway
// (WAF_v2) ingress, for a company website. This is a self-contained
// "webplat" workload, separate from the "secops" monitoring platform
// deployed by bicep/main.bicep - it does not modify that template.
//
// What this template creates:
//   - VNet + 3 subnets (AKS nodes, Application Gateway, private endpoints)
//   - Private AKS cluster (no public API server), Entra ID + Azure RBAC for
//     Kubernetes auth, system + user node pools, Defender for Containers,
//     Azure Policy add-on, Key Vault Secrets Provider add-on, and the
//     ingress-application-gateway (AGIC) add-on
//   - Private Azure Container Registry (Premium, private endpoint, no admin
//     user) with AcrPull granted to the AKS kubelet identity
//   - Application Gateway (WAF_v2) shell that AGIC manages at runtime
//   - A dedicated Key Vault (RBAC-authorized) for TLS certificate delivery
//     to pods via the AKS Key Vault Secrets Provider add-on
//   - Diagnostic settings for AKS + ACR into the SAME existing Log Analytics
//     Workspace the secops platform already monitors
//
// Deploy at resource-group scope, into a resource group dedicated to this
// workload (see docs/webplat-architecture.md). Requires an Entra ID group
// for cluster administrators to be created beforehand (see runbook).
// ============================================================================

targetScope = 'resourceGroup'

// -----------------------------------------------------------------------
// Core parameters
// -----------------------------------------------------------------------

@allowed([
  'dev'
  'prod'
])
@description('Target environment. Drives naming, node counts, and control-plane SKU tier.')
param environmentName string

@description('Azure region for new resources.')
param location string = resourceGroup().location

@minLength(2)
@maxLength(20)
@description('Short organization prefix used in CAF resource names, e.g. \'itsolutions\'.')
param orgPrefix string

@description('Workload name used in CAF resource names.')
param workloadName string = 'webplat'

@description('Instance suffix for CAF resource names (e.g. \'001\') - increment to support multiple parallel deployments.')
param instance string = '001'

@description('Short region code used in CAF resource names, e.g. \'eus\' for East US.')
param regionCode string = 'eus'

@description('Standard tags applied to every resource created by this template.')
param tags object = {
  environment: environmentName
  workload: workloadName
  managedBy: 'bicep'
  repository: 'azure-security-operations-platform'
}

// -----------------------------------------------------------------------
// Existing platform dependencies
// -----------------------------------------------------------------------

@description('Name of the EXISTING Log Analytics Workspace with Microsoft Sentinel enabled - AKS/ACR diagnostics and Defender for Containers alerts feed into the same workspace the secops platform already monitors.')
param existingLogAnalyticsWorkspaceName string

@description('Name of the resource group containing the existing Log Analytics Workspace. Defaults to this deployment\'s resource group.')
param existingLogAnalyticsWorkspaceResourceGroup string = resourceGroup().name

// -----------------------------------------------------------------------
// Cluster access
// -----------------------------------------------------------------------

@description('Entra ID group object ID for AKS administrators (e.g. "AKS-WebPlat-Admins"). Members can operate the private cluster via `az aks command invoke`. Required - the cluster has no static admin credentials.')
param aksAdminsGroupObjectId string

// -----------------------------------------------------------------------
// Networking
// -----------------------------------------------------------------------

@description('Address space for the platform VNet.')
param vnetAddressPrefix string = '10.30.0.0/16'

@description('Address prefix for the AKS node subnet.')
param aksSubnetPrefix string = '10.30.0.0/20'

@description('Address prefix for the Application Gateway subnet.')
param appGwSubnetPrefix string = '10.30.16.0/24'

@description('Address prefix for the private endpoint subnet.')
param peSubnetPrefix string = '10.30.17.0/24'

// -----------------------------------------------------------------------
// AKS sizing
// -----------------------------------------------------------------------

@description('Kubernetes version.')
param kubernetesVersion string = '1.29.7'

@description('VM size for the system node pool.')
param systemNodeVmSize string = 'Standard_D2s_v5'

@description('VM size for the user (workload) node pool.')
param userNodeVmSize string = 'Standard_D2s_v5'

@description('Node count for the system pool.')
param systemNodeCount int = (environmentName == 'prod') ? 3 : 2

@description('Minimum autoscale node count for the user pool.')
param userNodeMinCount int = (environmentName == 'prod') ? 2 : 1

@description('Maximum autoscale node count for the user pool.')
param userNodeMaxCount int = (environmentName == 'prod') ? 5 : 3

// -----------------------------------------------------------------------
// Naming (CAF: <resource-type>-<workload>-<env>-<region>-<instance>)
// -----------------------------------------------------------------------

var namePrefix = '${orgPrefix}-${workloadName}-${environmentName}-${regionCode}-${instance}'
var vnetName = 'vnet-${namePrefix}'
var acrName = toLower(take(replace('acr${orgPrefix}${workloadName}${environmentName}${instance}', '-', ''), 50))
var aksName = 'aks-${namePrefix}'
var appGatewayName = 'agw-${namePrefix}'
var publicIpName = 'pip-${namePrefix}'
var keyVaultName = take(replace('kv-${workloadName}-${environmentName}-${uniqueString(resourceGroup().id, instance)}', '-', ''), 24)

// -----------------------------------------------------------------------
// Existing resource references
// -----------------------------------------------------------------------

resource existingLogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: existingLogAnalyticsWorkspaceName
  scope: resourceGroup(existingLogAnalyticsWorkspaceResourceGroup)
}

// =========================================================================
// 1. Networking
// =========================================================================
module network '../modules/network.bicep' = {
  name: 'deploy-network'
  params: {
    vnetName: vnetName
    location: location
    vnetAddressPrefix: vnetAddressPrefix
    aksSubnetPrefix: aksSubnetPrefix
    appGwSubnetPrefix: appGwSubnetPrefix
    peSubnetPrefix: peSubnetPrefix
    tags: tags
  }
}

// =========================================================================
// 2. Key Vault (TLS certificate storage; RBAC-authorized, no access policies)
// =========================================================================
module keyVault '../modules/key-vault.bicep' = {
  name: 'deploy-webplat-key-vault'
  params: {
    keyVaultName: keyVaultName
    location: location
    publicNetworkAccessEnabled: false
    softDeleteRetentionInDays: (environmentName == 'prod') ? 90 : 30
    tags: tags
  }
}

// =========================================================================
// 3. Application Gateway (WAF_v2 shell - AGIC manages listeners/rules)
// =========================================================================
module appGwIngress '../modules/appgw-ingress.bicep' = {
  name: 'deploy-appgw-ingress'
  params: {
    appGatewayName: appGatewayName
    publicIpName: publicIpName
    location: location
    appGwSubnetId: network.outputs.appGwSubnetId
    autoscaleMinCapacity: 1
    autoscaleMaxCapacity: (environmentName == 'prod') ? 3 : 2
    tags: tags
  }
}

// =========================================================================
// 4. Container Registry (private, no admin user)
// =========================================================================
module acr '../modules/acr.bicep' = {
  name: 'deploy-acr'
  params: {
    acrName: acrName
    location: location
    vnetId: network.outputs.vnetId
    privateEndpointSubnetId: network.outputs.peSubnetId
    tags: tags
  }
}

// =========================================================================
// 5. AKS (private cluster, Entra ID + Azure RBAC, AGIC + Key Vault CSI add-ons)
// =========================================================================
module aks '../modules/aks.bicep' = {
  name: 'deploy-aks'
  params: {
    clusterName: aksName
    location: location
    environmentName: environmentName
    dnsPrefix: namePrefix
    kubernetesVersion: kubernetesVersion
    aksSubnetId: network.outputs.aksSubnetId
    systemNodeVmSize: systemNodeVmSize
    userNodeVmSize: userNodeVmSize
    systemNodeCount: systemNodeCount
    userNodeMinCount: userNodeMinCount
    userNodeMaxCount: userNodeMaxCount
    aksAdminsGroupObjectId: aksAdminsGroupObjectId
    logAnalyticsWorkspaceId: existingLogAnalyticsWorkspace.id
    appGatewayId: appGwIngress.outputs.appGatewayId
    tags: tags
  }
}

// =========================================================================
// 6. RBAC: AKS kubelet identity -> AcrPull on the registry (no stored
//    credentials, no admin user - this is the only way nodes can pull)
// =========================================================================
resource acrRef 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: acrName
}

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acrRef.id, aksName, 'AcrPull')
  scope: acrRef
  properties: {
    principalId: aks.outputs.kubeletIdentityObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    description: 'Allows AKS nodes to pull images from the webplat registry via their kubelet managed identity.'
  }
}

// =========================================================================
// 7. RBAC: AKS Key Vault Secrets Provider add-on identity -> read access on
//    the Key Vault (delivers the TLS certificate into pods via CSI, synced
//    into a Kubernetes TLS Secret consumed by the Ingress - see k8s/base/)
// =========================================================================
resource keyVaultRef 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource keyVaultSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultRef.id, aksName, 'KeyVaultSecretsUser')
  scope: keyVaultRef
  properties: {
    principalId: aks.outputs.keyVaultSecretsProviderIdentityObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    description: 'Allows the AKS Key Vault Secrets Provider add-on to read the TLS secret for CSI sync into the demo-web namespace.'
  }
}

resource keyVaultCertUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultRef.id, aksName, 'KeyVaultCertificateUser')
  scope: keyVaultRef
  properties: {
    principalId: aks.outputs.keyVaultSecretsProviderIdentityObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'db79e9a7-68ee-4b58-9aeb-b90e7c24fcba') // Key Vault Certificate User
    description: 'Allows the AKS Key Vault Secrets Provider add-on to read the TLS certificate object for CSI sync.'
  }
}

// =========================================================================
// 8. Diagnostic settings -> existing Log Analytics Workspace
// =========================================================================
module diagAks '../modules/diagnostic-settings.bicep' = {
  name: 'deploy-diag-aks'
  params: {
    targetResourceType: 'AKS'
    targetResourceName: aksName
    logAnalyticsWorkspaceId: existingLogAnalyticsWorkspace.id
    diagnosticSettingName: 'diag-to-law'
  }
  dependsOn: [
    aks
  ]
}

module diagAcr '../modules/diagnostic-settings.bicep' = {
  name: 'deploy-diag-acr'
  params: {
    targetResourceType: 'ACR'
    targetResourceName: acrName
    logAnalyticsWorkspaceId: existingLogAnalyticsWorkspace.id
    diagnosticSettingName: 'diag-to-law'
  }
  dependsOn: [
    acr
  ]
}

module diagKeyVault '../modules/diagnostic-settings.bicep' = {
  name: 'deploy-diag-webplat-keyvault'
  params: {
    targetResourceType: 'KeyVault'
    targetResourceName: keyVaultName
    logAnalyticsWorkspaceId: existingLogAnalyticsWorkspace.id
    diagnosticSettingName: 'diag-to-law'
  }
  dependsOn: [
    keyVault
  ]
}

// -----------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------
output resourceGroupName string = resourceGroup().name
output aksName string = aks.outputs.aksName
output aksPrivateFqdn string = aks.outputs.privateFqdn
output acrName string = acr.outputs.acrName
output acrLoginServer string = acr.outputs.loginServer
output appGatewayPublicIp string = appGwIngress.outputs.publicIpAddress
output keyVaultName string = keyVault.outputs.keyVaultName
