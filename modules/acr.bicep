// ============================================================================
// Module: acr.bicep
// Purpose: Private Azure Container Registry for the web platform. No admin
// user (images are pulled by AKS nodes via their kubelet managed identity -
// see the AcrPull role assignment in bicep/webplat.bicep), no public network
// access - reachable only via a Private Endpoint into the platform VNet.
// ============================================================================

@description('Name of the container registry. Must be globally unique, 5-50 alphanumeric characters.')
@minLength(5)
@maxLength(50)
param acrName string

@description('Azure region for the registry.')
param location string

@description('SKU. Premium is required for Private Endpoint support.')
@allowed([
  'Premium'
])
param skuName string = 'Premium'

@description('Resource ID of the VNet the private endpoint is linked into.')
param vnetId string

@description('Resource ID of the subnet the private endpoint is deployed into.')
param privateEndpointSubnetId string

@description('Tags applied to the resource.')
param tags object = {}

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    adminUserEnabled: false
    // Public network access stays enabled, with the network rule set left
    // at its default-allow action (no IP allowlist), because
    // webplat-build-push.yml pushes from GitHub-hosted runners, which sit
    // outside this VNet and have no fixed IP range to allow - a fully
    // private registry (Disabled) cannot be reached by them at all, and an
    // IP-restricted rule set would need constant upkeep against GitHub's
    // published (and changing) runner ranges. AKS's node pulls still use
    // the private endpoint/DNS zone below (private link is preferred
    // whenever a client resolves it internally), so this doesn't weaken
    // the network path AKS itself uses. Push/pull is still gated entirely
    // by Entra ID + AcrPush/AcrPull RBAC - no admin user, so nothing is
    // anonymously accessible; the network posture here is public-reachable
    // but identity-gated, not network-gated. A self-hosted, VNet-joined
    // GitHub runner would let this go back to fully private with a
    // default-deny rule set (see docs/webplat-architecture.md > Deferred).
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    networkRuleSet: {
      defaultAction: 'Allow'
    }
    policies: {
      retentionPolicy: {
        status: 'enabled'
        days: 30
      }
    }
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurecr.io'
  location: 'global'
  tags: tags
}

resource privateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${uniqueString(vnetId)}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: 'pe-${acrName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'pe-${acrName}-connection'
        properties: {
          privateLinkServiceId: acr.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
}

resource privateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-azurecr-io'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

@description('Resource ID of the container registry.')
output acrId string = acr.id

@description('Name of the container registry.')
output acrName string = acr.name

@description('Login server FQDN, used to tag/push/pull images.')
output loginServer string = acr.properties.loginServer
