// ============================================================================
// Module: network.bicep
// Purpose: VNet + 3 subnets for the secure AKS web platform:
//   - snet-aks   : AKS nodes (Azure CNI Overlay - pod IPs come from an
//                  overlay range, not this subnet, so it stays small)
//   - snet-appgw : dedicated subnet required by Application Gateway
//   - snet-pe    : private endpoints (ACR)
// Each subnet gets its own NSG. Only the App Gateway subnet is reachable from
// the Internet; AKS and the private-endpoint subnet are reachable only from
// within the VNet.
// ============================================================================

@description('Name of the VNet.')
param vnetName string

@description('Azure region for all network resources.')
param location string

@description('Address space for the VNet.')
param vnetAddressPrefix string = '10.30.0.0/16'

@description('Name of the AKS node subnet.')
param aksSubnetName string = 'snet-aks'

@description('Address prefix for the AKS node subnet.')
param aksSubnetPrefix string = '10.30.0.0/20'

@description('Name of the Application Gateway subnet.')
param appGwSubnetName string = 'snet-appgw'

@description('Address prefix for the Application Gateway subnet.')
param appGwSubnetPrefix string = '10.30.16.0/24'

@description('Name of the private endpoint subnet (ACR).')
param peSubnetName string = 'snet-pe'

@description('Address prefix for the private endpoint subnet.')
param peSubnetPrefix string = '10.30.17.0/24'

@description('Tags applied to every resource in this module.')
param tags object = {}

// -----------------------------------------------------------------------
// NSGs
// -----------------------------------------------------------------------

// Application Gateway v2 requires inbound access from the GatewayManager
// service tag (backend health probes / control-plane management) on
// 65200-65535, plus 80/443 from the Internet for the public site.
resource nsgAppGw 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-${appGwSubnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-GatewayManager-Inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '65200-65535'
        }
      }
      {
        name: 'Allow-Internet-Https-Inbound'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'Allow-Internet-Http-Inbound'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

// AKS nodes are never reached directly from the Internet - all public
// traffic must transit Application Gateway. VNet-internal traffic (App
// Gateway -> pods, node -> node) is allowed by the NSG's default rules.
resource nsgAks 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-${aksSubnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Deny-Internet-Inbound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// Private endpoints (ACR) are only ever resolved/reached from inside the
// VNet - explicitly deny anything arriving from the Internet.
resource nsgPe 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-${peSubnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Deny-Internet-Inbound'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// -----------------------------------------------------------------------
// VNet + subnets
// -----------------------------------------------------------------------

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: aksSubnetName
        properties: {
          addressPrefix: aksSubnetPrefix
          networkSecurityGroup: {
            id: nsgAks.id
          }
        }
      }
      {
        name: appGwSubnetName
        properties: {
          addressPrefix: appGwSubnetPrefix
          networkSecurityGroup: {
            id: nsgAppGw.id
          }
        }
      }
      {
        name: peSubnetName
        properties: {
          addressPrefix: peSubnetPrefix
          networkSecurityGroup: {
            id: nsgPe.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

@description('Resource ID of the VNet.')
output vnetId string = vnet.id

@description('Resource ID of the AKS node subnet.')
output aksSubnetId string = vnet.properties.subnets[0].id

@description('Resource ID of the Application Gateway subnet.')
output appGwSubnetId string = vnet.properties.subnets[1].id

@description('Resource ID of the private endpoint subnet.')
output peSubnetId string = vnet.properties.subnets[2].id
