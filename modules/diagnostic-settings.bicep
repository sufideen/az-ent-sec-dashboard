// ============================================================================
// Module: diagnostic-settings.bicep
// Purpose: Enable diagnostic settings -> Log Analytics Workspace for the
// platform resources this repo owns (Key Vault, the alerting Logic App).
//
// NOTE ON SCOPE: Bicep requires the "scope" of an extension resource (like
// Microsoft.Insights/diagnosticSettings) to be a symbolic resource reference
// of a concrete type known at compile time - a raw resourceId() string is
// not accepted (BCP036). Because this platform's diagnostic-settings targets
// are known (Key Vault, Logic App), this module exposes one branch per
// supported resource type rather than a fake "generic by resourceId" module
// that would not actually compile/deploy correctly.
//
// For diagnostic settings across the BROADER Azure estate (arbitrary VMs,
// storage accounts, AKS clusters, etc.), the CAF/enterprise-recommended
// mechanism is an Azure Policy DeployIfNotExists assignment (Azure Policy is
// already enabled in this environment) - see docs/architecture.md.
// ============================================================================

@allowed([
  'KeyVault'
  'LogicApp'
])
@description('The platform resource type to enable diagnostics for.')
param targetResourceType string

@description('Name of the target resource (Key Vault name or Logic App name).')
param targetResourceName string

@description('Resource ID of the destination Log Analytics Workspace.')
param logAnalyticsWorkspaceId string

@description('Name of the diagnostic setting.')
param diagnosticSettingName string = 'diag-to-law'

@description('Log retention in days (0 = use workspace retention / no explicit override).')
param retentionInDays int = 0

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = if (targetResourceType == 'KeyVault') {
  name: targetResourceName
}

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' existing = if (targetResourceType == 'LogicApp') {
  name: targetResourceName
}

resource diagKeyVault 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (targetResourceType == 'KeyVault') {
  name: diagnosticSettingName
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
        retentionPolicy: {
          enabled: retentionInDays > 0
          days: retentionInDays
        }
      }
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: retentionInDays > 0
          days: retentionInDays
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: retentionInDays > 0
          days: retentionInDays
        }
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
        retentionPolicy: {
          enabled: retentionInDays > 0
          days: retentionInDays
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: retentionInDays > 0
          days: retentionInDays
        }
      }
    ]
  }
}

output diagnosticSettingName string = diagnosticSettingName
