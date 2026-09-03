using 'main.bicep'

param environmentName = 'dev'
param location = 'eastus'
param orgPrefix = 'contoso'
param workloadName = 'secops'
param instance = '001'
param regionCode = 'eus'

param existingLogAnalyticsWorkspaceName = 'log-contoso-security-eus-001'
param existingLogAnalyticsWorkspaceResourceGroup = 'rg-contoso-security-eus-001'

param actionGroupEmailReceivers = [
  {
    name: 'soc-team'
    emailAddress: 'soc-dev@contoso.com'
  }
]

// Populate at deploy time from a pipeline secret variable, e.g.:
//   --parameters teamsWebhookUrl=$(TEAMS_WEBHOOK_URL_DEV)
// Never hard-code a real webhook URL in this file.
param teamsWebhookUrl = ''
param enableTeamsAlerting = false

param keyVaultPublicNetworkAccessEnabled = true
param diagnosticRetentionInDays = 30
param enableAnalyticsRules = true

// Entra ID group object IDs - replace with real group IDs for the dev tenant.
param socAnalystsGroupObjectId = ''
param securityAdminsGroupObjectId = ''
param executivesGroupObjectId = ''
param auditorsGroupObjectId = ''

param tags = {
  environment: 'dev'
  workload: 'secops'
  managedBy: 'bicep'
  repository: 'azure-security-operations-platform'
  costCenter: 'it-security-dev'
}
