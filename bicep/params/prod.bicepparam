using '../main.bicep'

param environmentName = 'prod'
param location = 'eastus'
param orgPrefix = 'itsolutions'
param workloadName = 'secops'
param instance = '001'
param regionCode = 'eus'

param existingLogAnalyticsWorkspaceName = 'log-itsolutions-security-eus-001'
param existingLogAnalyticsWorkspaceResourceGroup = 'rg-itsolutions-security-eus-001'

param actionGroupEmailReceivers = [
  {
    name: 'soc-team'
    emailAddress: 'soc@itsolutions.com'
  }
  {
    name: 'security-admins'
    emailAddress: 'secadmins@itsolutions.com'
  }
  {
    name: 'ciso-office'
    emailAddress: 'ciso@itsolutions.com'
  }
]

// Populate at deploy time from a Key Vault-backed pipeline secret variable, e.g.:
//   --parameters teamsWebhookUrl=$(TEAMS_WEBHOOK_URL_PROD)
// Requires manual approval gate before this parameter file is used - see
// pipelines/azure-devops/azure-pipelines.yml (DeployProd stage).
param teamsWebhookUrl = ''
param enableTeamsAlerting = true

param keyVaultPublicNetworkAccessEnabled = false
param diagnosticRetentionInDays = 365
param enableAnalyticsRules = true

// Entra ID group object IDs - replace with real group IDs for the prod tenant.
param socAnalystsGroupObjectId = ''
param securityAdminsGroupObjectId = ''
param executivesGroupObjectId = ''
param auditorsGroupObjectId = ''

param tags = {
  environment: 'prod'
  workload: 'secops'
  managedBy: 'bicep'
  repository: 'azure-security-operations-platform'
  costCenter: 'it-security-prod'
  dataClassification: 'confidential'
}
