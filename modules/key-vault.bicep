// ============================================================================
// Module: key-vault.bicep
// Purpose: Dedicated Key Vault for the SecOps platform. Stores the Teams
// incoming-webhook URL and any other alerting secrets. Uses RBAC
// authorization (not access policies), soft-delete + purge protection,
// and defaults to denying public network access (Private Endpoint pattern).
// ============================================================================

@description('Name of the Key Vault. Must be globally unique, 3-24 chars.')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Azure region for the Key Vault.')
param location string

@description('Azure AD tenant ID.')
param tenantId string = subscription().tenantId

@description('Enable public network access. Set to false in test/prod and use a Private Endpoint.')
param publicNetworkAccessEnabled bool = false

@description('IP/subnet allow-list applied when public network access is enabled (break-glass/dev only).')
param networkAcls object = {
  bypass: 'AzureServices'
  defaultAction: 'Deny'
  ipRules: []
  virtualNetworkRules: []
}

@description('Soft-delete retention in days.')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('Tags applied to the resource.')
param tags object = {}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: true
    publicNetworkAccess: publicNetworkAccessEnabled ? 'Enabled' : 'Disabled'
    networkAcls: networkAcls
  }
}

@description('Resource ID of the Key Vault.')
output keyVaultId string = keyVault.id

@description('Name of the Key Vault.')
output keyVaultName string = keyVault.name

@description('URI of the Key Vault, used for MSI-authenticated REST calls (e.g. from the alerting Logic App).')
output keyVaultUri string = keyVault.properties.vaultUri
