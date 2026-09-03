// ============================================================================
// Module: action-groups.bicep
// Purpose: Azure Monitor Action Group used by Sentinel Analytics Rules /
// Azure Monitor alerts to fan out notifications to email and the Teams
// alerting Logic App.
// ============================================================================

@description('Name of the action group (CAF: ag-<workload>-<env>-<region>-<instance>).')
param actionGroupName string

@description('Short name shown in notifications. Max 12 characters.')
@maxLength(12)
param actionGroupShortName string

@description('Whether the action group is enabled.')
param enabled bool = true

@description('Email addresses to notify, e.g. [{ name: \'soc-team\', emailAddress: \'soc@contoso.com\' }]')
param emailReceivers array = []

@description('Resource ID of the Logic App to invoke for Teams notifications (optional).')
param logicAppResourceId string = ''

@description('Callback URL of the Logic App HTTP trigger (optional, required if logicAppResourceId is set).')
@secure()
param logicAppCallbackUrl string = ''

@description('Azure region. Action Groups are global; use \'Global\'.')
param location string = 'Global'

@description('Tags applied to the resource.')
param tags object = {}

var logicAppReceivers = !empty(logicAppResourceId) ? [
  {
    name: 'teamsAlerting'
    resourceId: logicAppResourceId
    callbackUrl: logicAppCallbackUrl
    useCommonAlertSchema: true
  }
] : []

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: location
  tags: tags
  properties: {
    groupShortName: actionGroupShortName
    enabled: enabled
    emailReceivers: [
      for r in emailReceivers: {
        name: r.name
        emailAddress: r.emailAddress
        useCommonAlertSchema: true
      }
    ]
    logicAppReceivers: logicAppReceivers
  }
}

output actionGroupId string = actionGroup.id
output actionGroupName string = actionGroup.name
