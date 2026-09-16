// ============================================================================
// Module: diagnostic-settings.bicep
// Purpose: Enable diagnostic settings -> Log Analytics Workspace for the
// platform resources this repo owns (Key Vault, the alerting Logic App, and
// - for the webplat AKS/ACR workload - the AKS cluster and container
// registry).
//
// NOTE ON SCOPE: Bicep requires the "scope" of an extension resource (like
// Microsoft.Insights/diagnosticSettings) to be a symbolic resource reference
// of a concrete type known at compile time - a raw resourceId() string is
// not accepted (BCP036). Because this platform's diagnostic-settings targets
// are known (Key Vault, Logic App, AKS, ACR), this module exposes one branch
// per supported resource type rather than a fake "generic by resourceId"
// module that would not actually compile/deploy correctly.
//
// For diagnostic settings across the BROADER Azure estate (arbitrary VMs,
// storage accounts, etc.), the CAF/enterprise-recommended mechanism is an
// Azure Policy DeployIfNotExists assignment (Azure Policy is already enabled
// in this environment) - see docs/architecture.md.
// ============================================================================

@allowed([
  'KeyVault'
  'LogicApp'
  'AKS'
  'ACR'
])
@description('The platform resource type to enable diagnostics for.')
param targetResourceType string

@description('Name of the target resource (Key Vault name or Logic App name).')
param targetResourceName string

@description('Resource ID of the destination Log Analytics Workspace.')
param logAnalyticsWorkspaceId string

@description('Name of the diagnostic setting.')
param diagnosticSettingName string = 'diag-to-law'

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = if (targetResourceType == 'KeyVault') {
  name: targetResourceName
}

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' existing = if (targetResourceType == 'LogicApp') {
  name: targetResourceName
}

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-11-01' existing = if (targetResourceType == 'AKS') {
  name: targetResourceName
}

resource acrRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = if (targetResourceType == 'ACR') {
  name: targetResourceName
}

// NOTE ON RETENTION: Azure deprecated the retentionPolicy property on
// diagnostic settings - a NEW diagnostic setting is rejected outright with
// "Diagnostic settings does not support retention for new diagnostic
// settings" if retentionPolicy.enabled is set (verified against a live
// deployment). Log retention is configured at the Log Analytics Workspace
// level now (or per-table, via Basic Logs/Auxiliary Logs tiers - see
// docs/cost-estimates.md) - out of this module's and this repo's control
// either way, since the workspace is an `existing` resource this platform
// references but doesn't own.
resource diagKeyVault 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (targetResourceType == 'KeyVault') {
  name: diagnosticSettingName
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource diagLogicApp 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (targetResourceType == 'LogicApp') {
  name: diagnosticSettingName
  scope: logicApp
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource diagAks 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (targetResourceType == 'AKS') {
  name: diagnosticSettingName
  scope: aksCluster
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
      {
        category: 'kube-apiserver'
        enabled: true
      }
      {
        category: 'guard'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource diagAcr 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (targetResourceType == 'ACR') {
  name: diagnosticSettingName
  scope: acrRegistry
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output diagnosticSettingName string = diagnosticSettingName
