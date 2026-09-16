// ============================================================================
// Module: appgw-ingress.bicep
// Purpose: "Shell" Application Gateway (WAF_v2) that AKS's
// ingress-application-gateway (AGIC) add-on attaches to. AGIC reconfigures
// the gateway's listeners/backend pools/routing rules at runtime to match
// Kubernetes Ingress objects, so this module only needs to stand up a
// minimal valid gateway (frontend IP, one placeholder listener/pool/rule) -
// it is intentionally NOT where per-app routing is defined.
// ============================================================================

@description('Name of the Application Gateway.')
param appGatewayName string

@description('Name of the public IP used as the gateway\'s frontend.')
param publicIpName string

@description('Azure region.')
param location string

@description('Resource ID of the dedicated Application Gateway subnet.')
param appGwSubnetId string

@description('Autoscale minimum capacity (Application Gateway compute units).')
param autoscaleMinCapacity int = 1

@description('Autoscale maximum capacity (Application Gateway compute units).')
param autoscaleMaxCapacity int = 3

@description('Tags applied to every resource in this module.')
param tags object = {}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource appGateway 'Microsoft.Network/applicationGateways@2023-09-01' = {
  name: appGatewayName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    autoscaleConfiguration: {
      minCapacity: autoscaleMinCapacity
      maxCapacity: autoscaleMaxCapacity
    }
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: appGwSubnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port80'
        properties: {
          port: 80
        }
      }
    ]
    // Placeholder backend pool/settings/listener/rule - required for the
    // gateway to deploy in a valid state. AGIC takes over and replaces
    // these once the ingress-application-gateway AKS add-on is running.
    backendAddressPools: [
      {
        name: 'placeholder-pool'
        properties: {
          backendAddresses: []
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'placeholder-http-settings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 20
        }
      }
    ]
    httpListeners: [
      {
        name: 'placeholder-listener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'port80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'placeholder-rule'
        properties: {
          ruleType: 'Basic'
          priority: 1000
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'placeholder-listener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'placeholder-pool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'placeholder-http-settings')
          }
        }
      }
    ]
  }
}

@description('Resource ID of the Application Gateway, passed to the AKS ingressApplicationGateway add-on.')
output appGatewayId string = appGateway.id

@description('Public IP address of the gateway (the site\'s public entry point).')
output publicIpAddress string = publicIp.properties.ipAddress

@description('Resource ID of the public IP.')
output publicIpId string = publicIp.id
