// ============================================================================
// Module: rbac.bicep
// Purpose: Least-privilege RBAC role assignments for the SecOps platform,
// scoped directly to the Log Analytics Workspace (which hosts Sentinel).
// Assigning at the workspace scope (rather than subscription/RG) keeps the
// blast radius of each grant limited to security data + Sentinel, per
// Zero Trust / least-privilege principles.
//
// Callers pass an array of {principalId, principalType, roleDefinitionId}
// objects built from the curated role GUIDs in this module's outputs, so
// the same module works for SOC analysts, security admins, executives,
// auditors, and the platform's own managed identities.
// ============================================================================

@description('Name of the existing Log Analytics Workspace (Sentinel-enabled) to scope role assignments to. This module must be invoked with `scope: resourceGroup(<workspace-resource-group>)` by its caller when the workspace lives in a different resource group than the parent deployment - see bicep/main.bicep.')
param logAnalyticsWorkspaceName string

@description('Array of role assignments to create: [{ principalId, principalType: \'User\'|\'Group\'|\'ServicePrincipal\', roleDefinitionId, assignmentNameSeed }]')
param roleAssignments array = []

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

@batchSize(1)
resource assignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for ra in roleAssignments: {
    name: guid(logAnalyticsWorkspace.id, ra.principalId, ra.roleDefinitionId, ra.assignmentNameSeed)
    scope: logAnalyticsWorkspace
    properties: {
      principalId: ra.principalId
      principalType: ra.principalType
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', ra.roleDefinitionId)
      description: 'Managed by azure-security-operations-platform IaC - do not modify manually.'
    }
  }
]

// ----------------------------------------------------------------------------
// Curated built-in role definition GUIDs (outputs so main.bicep / consumers
// can reference them by name instead of hard-coding GUIDs everywhere).
// ----------------------------------------------------------------------------
@description('Built-in role definition GUIDs used across the SecOps platform.')
output roles object = {
  microsoftSentinelReader: '8d289c81-5878-46d4-8554-54e1e3d8b5cb'
  microsoftSentinelResponder: '3e150937-b8fe-4cfb-8069-0eaf05ecd056'
  microsoftSentinelContributor: 'ab8e14d6-4a74-4a29-9ba8-549422addade'
  microsoftSentinelAutomationContributor: 'f4c81013-99ee-4d62-a7ee-b3f1f648599a'
  logAnalyticsReader: '73c42c96-874c-492b-b04d-ab87d138a893'
  logAnalyticsContributor: '92aaf0da-9dab-42b6-94a3-d43ce8d16293'
  monitoringReader: '43d0d8ad-25c7-4714-9337-8ba259a9fe05'
  monitoringContributor: '749f88d5-cbae-40b8-bcfc-e573ddc772fa'
  workbookReader: 'b279062a-9be3-42a0-92ae-8b3cf002ec4d'
  workbookContributor: 'e8ddcd69-c73f-4f9f-9844-4100522f16ad'
  securityReader: '39bc4728-0917-49c7-9d2c-d95423bc2eb4'
  securityAdmin: 'fb1c8493-542b-48eb-b624-b4c8fea62acd'
  keyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
  logicAppContributor: '87a39d53-fc1b-424a-814c-f7e04687dc9e'
}

output assignmentIds array = [for i in range(0, length(roleAssignments)): assignments[i].id]
