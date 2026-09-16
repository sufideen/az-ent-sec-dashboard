using '../webplat.bicep'

param environmentName = 'dev'
param location = 'uksouth'
param orgPrefix = 'itsolutions'
param workloadName = 'webplat'
param instance = '001'
param regionCode = 'uks'

param existingLogAnalyticsWorkspaceName = 'law-ictlabs-central-dev-uksouth'
param existingLogAnalyticsWorkspaceResourceGroup = 'rg-ictlabs-connectivity-dev-uksouth'

// Entra ID group object ID for "AKS-WebPlat-Admins" - replace with the real
// group ID for the dev tenant before deploying. Members get Azure RBAC
// cluster-admin and can run `az aks command invoke` against the private
// cluster (see docs/webplat-architecture.md > Administrator access).
param aksAdminsGroupObjectId = ''

param vnetAddressPrefix = '10.30.0.0/16'
param aksSubnetPrefix = '10.30.0.0/20'
param appGwSubnetPrefix = '10.30.16.0/24'
param peSubnetPrefix = '10.30.17.0/24'

param kubernetesVersion = '1.36.3'
param systemNodeVmSize = 'Standard_D2s_v4'
param userNodeVmSize = 'Standard_D2s_v4'
param systemNodeCount = 2
param userNodeMinCount = 1
param userNodeMaxCount = 3

param tags = {
  environment: 'dev'
  workload: 'webplat'
  managedBy: 'bicep'
  repository: 'azure-security-operations-platform'
  costCenter: 'it-webplat-dev'
}
