using '../webplat.bicep'

param environmentName = 'prod'
param location = 'uksouth'
param orgPrefix = 'itsolutions'
param workloadName = 'webplat'
param instance = '001'
param regionCode = 'uks'

// Replace with the real name/resource group of your existing Log Analytics
// Workspace - run `az monitor log-analytics workspace list -o table` to find it.
param existingLogAnalyticsWorkspaceName = 'log-itsolutions-security-uks-001'
param existingLogAnalyticsWorkspaceResourceGroup = 'rg-itsolutions-security-uks-001'

// Entra ID group object ID for "AKS-WebPlat-Admins" - replace with the real
// group ID for the prod tenant before deploying. Members get Azure RBAC
// cluster-admin and can run `az aks command invoke` against the private
// cluster (see docs/webplat-architecture.md > Administrator access).
param aksAdminsGroupObjectId = ''

param vnetAddressPrefix = '10.31.0.0/16'
param aksSubnetPrefix = '10.31.0.0/20'
param appGwSubnetPrefix = '10.31.16.0/24'
param peSubnetPrefix = '10.31.17.0/24'

param kubernetesVersion = '1.29.7'
param systemNodeVmSize = 'Standard_D2s_v5'
param userNodeVmSize = 'Standard_D2s_v5'
param systemNodeCount = 3
param userNodeMinCount = 2
param userNodeMaxCount = 5

param tags = {
  environment: 'prod'
  workload: 'webplat'
  managedBy: 'bicep'
  repository: 'azure-security-operations-platform'
  costCenter: 'it-webplat-prod'
  dataClassification: 'confidential'
}
