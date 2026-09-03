// ============================================================================
// Module: logic-app-alerting.bicep
// Purpose: Consumption Logic App triggered by an Azure Monitor Action Group
// (Common Alert Schema). It retrieves the Teams incoming-webhook URL from
// Key Vault at *runtime* using its user-assigned managed identity (no
// secrets stored in the workflow definition or source control), then posts
// a formatted adaptive-card style message to Teams.
//
// Security: authenticates to Key Vault via Managed Identity
// (audience https://vault.azure.net); requires the identity to hold the
// "Key Vault Secrets User" RBAC role on the target vault (see rbac.bicep).
// ============================================================================

@description('Name of the Logic App (CAF: logic-<workload>-alerting-<env>-<region>-<instance>).')
param logicAppName string

@description('Azure region for the Logic App.')
param location string

@description('Resource ID of the user-assigned managed identity used to call Key Vault.')
param userAssignedIdentityId string

@description('Vault URI of the Key Vault holding the Teams webhook secret, e.g. https://kv-secops-prod.vault.azure.net/')
param keyVaultUri string

@description('Name of the Key Vault secret containing the Teams incoming-webhook URL.')
param teamsWebhookSecretName string

@description('Whether the workflow is enabled.')
param enabled bool = true

@description('Tags applied to the resource.')
param tags object = {}

var keyVaultSecretGetUrl = '${keyVaultUri}secrets/${teamsWebhookSecretName}?api-version=7.4'

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    state: enabled ? 'Enabled' : 'Disabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {
        Receive_Azure_Monitor_Alert: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            method: 'POST'
            schema: {
              type: 'object'
              properties: {
                schemaId: {
                  type: 'string'
                }
                data: {
                  type: 'object'
                }
              }
            }
          }
        }
      }
      actions: {
        Get_Teams_Webhook_Secret: {
          type: 'Http'
          inputs: {
            method: 'GET'
            uri: keyVaultSecretGetUrl
            authentication: {
              type: 'ManagedServiceIdentity'
              identity: userAssignedIdentityId
              // Key Vault's MSI token audience is a fixed, cloud-specific constant
              // (not a callable resource endpoint), so environment() does not apply here.
              #disable-next-line no-hardcoded-env-urls
              audience: 'https://vault.azure.net'
            }
          }
          runAfter: {}
        }
        Parse_Secret_Response: {
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Get_Teams_Webhook_Secret\')'
            schema: {
              type: 'object'
              properties: {
                value: {
                  type: 'string'
                }
              }
            }
          }
          runAfter: {
            Get_Teams_Webhook_Secret: [
              'Succeeded'
            ]
          }
        }
        Compose_Teams_Card: {
          type: 'Compose'
          inputs: {
            '@type': 'MessageCard'
            '@context': 'https://schema.org/extensions'
            summary: 'Microsoft Sentinel Alert'
            themeColor: 'A80000'
            title: '🚨 Sentinel Alert: @{coalesce(triggerBody()?[\'data\']?[\'essentials\']?[\'alertRule\'], \'Unknown rule\')}'
            sections: [
              {
                facts: [
                  {
                    name: 'Severity'
                    value: '@{coalesce(triggerBody()?[\'data\']?[\'essentials\']?[\'severity\'], \'Unknown\')}'
                  }
                  {
                    name: 'Fired At'
                    value: '@{coalesce(triggerBody()?[\'data\']?[\'essentials\']?[\'firedDateTime\'], utcNow())}'
                  }
                  {
                    name: 'Monitor Condition'
                    value: '@{coalesce(triggerBody()?[\'data\']?[\'essentials\']?[\'monitorCondition\'], \'Fired\')}'
                  }
                  {
                    name: 'Alert Target Resource'
                    value: '@{coalesce(triggerBody()?[\'data\']?[\'essentials\']?[\'alertTargetIDs\'], \'\')}'
                  }
                ]
                markdown: true
              }
            ]
            potentialAction: [
              {
                '@type': 'OpenUri'
                name: 'View in Microsoft Sentinel'
                targets: [
                  {
                    os: 'default'
                    uri: 'https://portal.azure.com/#view/Microsoft_Azure_Security_Insights/MainMenuBlade/~/0'
                  }
                ]
              }
            ]
          }
          runAfter: {
            Parse_Secret_Response: [
              'Succeeded'
            ]
          }
        }
        Post_To_Teams: {
          type: 'Http'
          inputs: {
            method: 'POST'
            uri: '@body(\'Parse_Secret_Response\')?[\'value\']'
            headers: {
              'Content-Type': 'application/json'
            }
            body: '@outputs(\'Compose_Teams_Card\')'
          }
          runAfter: {
            Compose_Teams_Card: [
              'Succeeded'
            ]
          }
        }
      }
      outputs: {}
    }
  }
}

@description('Resource ID of the Logic App, used by action-groups.bicep.')
output logicAppResourceId string = logicApp.id

@description('Name of the Logic App.')
output logicAppName string = logicApp.name

@description('Resource ID of the HTTP trigger, required to fetch the callback URL for the action group.')
output triggerResourceId string = resourceId('Microsoft.Logic/workflows/triggers', logicApp.name, 'Receive_Azure_Monitor_Alert')
