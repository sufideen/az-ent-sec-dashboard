// ============================================================================
// Module: aks.bicep
// Purpose: Private AKS cluster for the web platform.
//   - No public API server (private_cluster + AKS-managed private DNS zone).
//   - Entra ID + Azure RBAC for Kubernetes authorization (no static admin
//     kubeconfig/certs) - cluster access is an Entra ID group membership.
//   - System + User node pools (workloads never land on the system pool).
//   - Defender for Containers + Azure Policy add-on, wired to the SAME
//     existing Log Analytics Workspace the rest of this repo already
//     monitors, so AKS becomes one more resource type in the existing
//     Sentinel/SOC pipeline.
//   - Key Vault Secrets Provider add-on (CSI driver) for TLS delivery to
//     pods, and the ingress-application-gateway (AGIC) add-on so Kubernetes
//     Ingress objects drive the Application Gateway's configuration.
// ============================================================================

@description('Name of the AKS cluster.')
param clusterName string

@description('Azure region.')
param location string

@allowed([
  'dev'
  'prod'
])
@description('Target environment. Drives the control-plane SKU tier and node counts.')
param environmentName string

@description('DNS prefix for the cluster.')
param dnsPrefix string

@description('Kubernetes version.')
param kubernetesVersion string

@description('Resource ID of the AKS node subnet.')
param aksSubnetId string

@description('VM size for the system node pool.')
param systemNodeVmSize string = 'Standard_D2s_v5'

@description('VM size for the user (workload) node pool.')
param userNodeVmSize string = 'Standard_D2s_v5'

@description('Node count for the system pool.')
param systemNodeCount int

@description('Minimum autoscale node count for the user pool.')
param userNodeMinCount int

@description('Maximum autoscale node count for the user pool.')
param userNodeMaxCount int

@description('Entra ID group object ID granted cluster-admin via Azure RBAC. Members can operate the cluster via `az aks command invoke`.')
param aksAdminsGroupObjectId string

@description('Resource ID of the existing Log Analytics Workspace for Container Insights and Defender for Containers.')
param logAnalyticsWorkspaceId string

@description('Resource ID of the Application Gateway the ingressApplicationGateway add-on attaches to.')
param appGatewayId string

@description('Tags applied to the resource.')
param tags object = {}

resource aks 'Microsoft.ContainerService/managedClusters@2023-11-01' = {
  name: clusterName
  location: location
  tags: tags
  sku: {
    name: 'Base'
    tier: environmentName == 'prod' ? 'Standard' : 'Free'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: dnsPrefix
    kubernetesVersion: kubernetesVersion
    // The default auto-generated node RG name (MC_<rg>_<cluster>_<region>)
    // exceeds Azure's 80-char limit once CAF-length names are combined -
    // set an explicit, shorter one instead.
    nodeResourceGroup: 'rg-nodes-${clusterName}'
    apiServerAccessProfile: {
      enablePrivateCluster: true
      privateDNSZone: 'system'
    }
    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        vmSize: systemNodeVmSize
        count: systemNodeCount
        osType: 'Linux'
        osSKU: 'AzureLinux'
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: aksSubnetId
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
        maxPods: 30
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPluginMode: 'overlay'
      networkPolicy: 'azure'
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
    }
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      adminGroupObjectIDs: !empty(aksAdminsGroupObjectId) ? [
        aksAdminsGroupObjectId
      ] : []
    }
    enableRBAC: true
    disableLocalAccounts: true
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
      defender: {
        securityMonitoring: {
          enabled: true
        }
        logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceId
      }
    }
    addonProfiles: {
      azurepolicy: {
        enabled: true
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
        }
      }
      ingressApplicationGateway: {
        enabled: true
        config: {
          applicationGatewayId: appGatewayId
        }
      }
    }
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
      nodeOSUpgradeChannel: 'NodeImage'
    }
  }
}

// Workloads never land on the system pool (CriticalAddonsOnly taint above) -
// the demo web app (and anything else) is scheduled onto this pool instead.
resource userPool 'Microsoft.ContainerService/managedClusters/agentPools@2023-11-01' = {
  parent: aks
  name: 'user'
  properties: {
    mode: 'User'
    vmSize: userNodeVmSize
    osType: 'Linux'
    osSKU: 'AzureLinux'
    type: 'VirtualMachineScaleSets'
    vnetSubnetID: aksSubnetId
    enableAutoScaling: true
    minCount: userNodeMinCount
    maxCount: userNodeMaxCount
    maxPods: 30
  }
}

// Weekly patch/node-image auto-upgrade maintenance window (Sun 02:00-06:00 UTC).
resource maintenanceConfig 'Microsoft.ContainerService/managedClusters/maintenanceConfigurations@2023-11-01' = {
  parent: aks
  name: 'aksManagedAutoUpgradeSchedule'
  properties: {
    maintenanceWindow: {
      schedule: {
        weekly: {
          intervalWeeks: 1
          dayOfWeek: 'Sunday'
        }
      }
      durationHours: 4
      utcOffset: '+00:00'
      startTime: '02:00'
    }
  }
}

@description('Resource ID of the AKS cluster.')
output aksId string = aks.id

@description('Name of the AKS cluster.')
output aksName string = aks.name

@description('Private FQDN of the API server (no public FQDN is assigned - private_cluster_enabled).')
output privateFqdn string = aks.properties.privateFQDN

@description('Object (principal) ID of the node kubelet identity - grant this AcrPull on the registry.')
output kubeletIdentityObjectId string = aks.properties.identityProfile.kubeletidentity.objectId

@description('Object (principal) ID of the Key Vault Secrets Provider add-on identity - grant this read access on the Key Vault for TLS delivery.')
output keyVaultSecretsProviderIdentityObjectId string = aks.properties.addonProfiles.azureKeyvaultSecretsProvider.identity.objectId

@description('OIDC issuer URL, for future workload-identity federated credentials.')
output oidcIssuerUrl string = aks.properties.oidcIssuerProfile.issuerURL
