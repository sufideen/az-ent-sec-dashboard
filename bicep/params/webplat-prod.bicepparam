using '../webplat.bicep'

param environmentName = 'prod'
param location = 'uksouth'
param orgPrefix = 'itsolutions'
param workloadName = 'webplat'
param instance = '001'
param regionCode = 'uks'

// NOTE: no dedicated prod Log Analytics Workspace exists yet in this
// subscription - pointed at the same dev-tier workspace as webplat-dev for
// now. Repoint this at a real prod workspace once one exists.
param existingLogAnalyticsWorkspaceName = 'law-ictlabs-central-dev-uksouth'
param existingLogAnalyticsWorkspaceResourceGroup = 'rg-ictlabs-connectivity-dev-uksouth'

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
