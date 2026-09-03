// ============================================================================
// Module: managed-identity.bicep
// Purpose: User-assigned managed identity for the SecOps alerting Logic App.
// Follows least-privilege: role assignments are granted by the caller
// (see modules/rbac.bicep) rather than inside this module.
// ============================================================================

@description('Name of the user-assigned managed identity. Must follow CAF naming: id-<workload>-<purpose>-<env>-<region>-<instance>')
param identityName string

@description('Azure region for the identity.')
param location string

@description('Tags applied to the resource.')
param tags object = {}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: tags
}

@description('Resource ID of the created managed identity.')
output identityId string = identity.id

@description('Principal (object) ID of the managed identity, used for role assignments.')
output principalId string = identity.properties.principalId

@description('Client ID of the managed identity, used for MSI-authenticated calls.')
output clientId string = identity.properties.clientId

@description('Name of the created managed identity.')
output identityName string = identity.name
