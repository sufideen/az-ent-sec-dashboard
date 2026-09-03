using 'main.bicep'

param environmentName = 'test'
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
    emailAddress: 'soc-test@contoso.com'
  }
  {
    name: 'security-admins'
    emailAddress: 'secadmins-test@contoso.com'
  }
]

// Populate at deploy time from a pipeline secret variable, e.g.:
//   --parameters teamsWebhookUrl=$(TEAMS_WEBHOOK_URL_TEST)
param teamsWebhookUrl = ''
param enableTeamsAlerting = true

param keyVaultPublicNetworkAccessEnabled = false
param diagnosticRetentionInDays = 90
param enableAnalyticsRules = true

// Entra ID group object IDs - replace with real group IDs for the test tenant.
param socAnalystsGroupObjectId = ''
param securityAdminsGroupObjectId = ''
param executivesGroupObjectId = ''
param auditorsGroupObjectId = ''

param tags = {
  environment: 'test'
  workload: 'secops'
  managedBy: 'bicep'
  repository: 'azure-security-operations-platform'
  costCenter: 'it-security-test'
}
