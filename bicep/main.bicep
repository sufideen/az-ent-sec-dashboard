// ============================================================================
// azure-security-operations-platform / bicep/main.bicep
//
// Orchestrator that deploys the Enterprise Security Dashboard platform on
// TOP of already-deployed foundational security services:
//   - Microsoft Sentinel (enabled on the existing Log Analytics Workspace)
//   - Defender for Cloud
//   - Entra ID (integrated with Sentinel)
//   - Azure Policy
//   - Zero Trust architecture
//
// This template does NOT create Sentinel, the Log Analytics Workspace, or
// Defender for Cloud - it references them as existing resources and adds:
//   - 3 Azure Workbooks (Executive / SOC / Zero Trust dashboards)
//   - 5 Sentinel Scheduled Analytics Rules (detections)
//   - A dedicated Key Vault for alerting secrets (RBAC-authorized)
//   - A user-assigned managed identity + Logic App for Teams notifications
//   - An Action Group wiring Sentinel/Monitor alerts to email + Teams
//   - Diagnostic settings for the platform's own resources
//   - Least-privilege RBAC role assignments for SOC/Security/Exec/Audit teams
//
// Deploy at resource-group scope, into the resource group that hosts (or is
// peered with) the existing Log Analytics Workspace. See docs/deployment-guide.md.
// ============================================================================

targetScope = 'resourceGroup'

// -----------------------------------------------------------------------
// Core parameters
// -----------------------------------------------------------------------

@allowed([
  'dev'
  'test'
  'prod'
])
@description('Target environment. Drives naming, retention, and safety defaults (e.g. public network access).')
param environmentName string

@description('Azure region for new resources.')
param location string = resourceGroup().location

@minLength(2)
@maxLength(20)
@description('Short organization prefix used in CAF resource names, e.g. \'itsolutions\'.')
param orgPrefix string

@description('Workload name used in CAF resource names.')
param workloadName string = 'secops'

@description('Instance suffix for CAF resource names (e.g. \'001\') - increment to support multiple parallel deployments.')
param instance string = '001'

@description('Short region code used in CAF resource names, e.g. \'eus\' for East US.')
param regionCode string = 'eus'

@description('Standard tags applied to every resource created by this template.')
param tags object = {
  environment: environmentName
  workload: workloadName
  managedBy: 'bicep'
  repository: 'azure-security-operations-platform'
}

// -----------------------------------------------------------------------
// Existing platform dependencies
// -----------------------------------------------------------------------

@description('Name of the EXISTING Log Analytics Workspace with Microsoft Sentinel enabled.')
param existingLogAnalyticsWorkspaceName string

@description('Name of the resource group containing the existing Log Analytics Workspace. Defaults to this deployment\'s resource group.')
param existingLogAnalyticsWorkspaceResourceGroup string = resourceGroup().name

// -----------------------------------------------------------------------
// Alerting / notifications
// -----------------------------------------------------------------------

@description('Email addresses notified by the Action Group, e.g. [{ name: \'soc-team\', emailAddress: \'soc@itsolutions.com\' }]')
param actionGroupEmailReceivers array = []

@description('Teams incoming-webhook URL. Pass via a pipeline secret variable (never commit to source). Stored in Key Vault, not in the template.')
@secure()
param teamsWebhookUrl string = ''

@description('Whether the Logic App / Action Group Teams integration is enabled. Set false if teamsWebhookUrl is not yet provisioned.')
param enableTeamsAlerting bool = true

// -----------------------------------------------------------------------
// Security / networking
// -----------------------------------------------------------------------

@description('Allow public network access to the platform Key Vault. Must be false in test/prod; use a Private Endpoint instead.')
param keyVaultPublicNetworkAccessEnabled bool = (environmentName == 'dev')

// -----------------------------------------------------------------------
// RBAC assignments (Zero Trust least privilege)
// -----------------------------------------------------------------------

@description('Entra ID group object ID for SOC Analysts. Granted Sentinel Responder + Log Analytics/Workbook Reader.')
param socAnalystsGroupObjectId string = ''

@description('Entra ID group object ID for Security Administrators. Granted Sentinel Contributor + Security Admin.')
param securityAdminsGroupObjectId string = ''

@description('Entra ID group object ID for Executives/Leadership. Granted read-only Sentinel + Workbook + Security Reader (Executive dashboard viewers).')
param executivesGroupObjectId string = ''

@description('Entra ID group object ID for Auditors/Compliance. Granted Security Reader + Log Analytics Reader.')
param auditorsGroupObjectId string = ''

@description('Enable the Sentinel Scheduled Analytics Rules deployed by this template.')
param enableAnalyticsRules bool = true

// -----------------------------------------------------------------------
// Naming (CAF: <resource-type>-<workload>-<env>-<region>-<instance>)
// -----------------------------------------------------------------------

var namePrefix = '${orgPrefix}-${workloadName}-${environmentName}-${regionCode}-${instance}'
var keyVaultName = take(replace('kv-${workloadName}-${environmentName}-${uniqueString(resourceGroup().id, instance)}', '-', ''), 24)
var managedIdentityName = 'id-${namePrefix}-logicapp'
var logicAppName = 'logic-${namePrefix}-alerting'
var actionGroupName = 'ag-${namePrefix}'
var actionGroupShortName = take('${workloadName}${environmentName}', 12)
var teamsWebhookSecretName = 'teams-webhook-url'
var logicAppTriggerName = 'Receive_Azure_Monitor_Alert'

// -----------------------------------------------------------------------
// Existing resource references
// -----------------------------------------------------------------------

resource existingLogAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: existingLogAnalyticsWorkspaceName
  scope: resourceGroup(existingLogAnalyticsWorkspaceResourceGroup)
}

// =========================================================================
// 1. Managed Identity (used by the alerting Logic App to read Key Vault)
// =========================================================================
module managedIdentity '../modules/managed-identity.bicep' = {
  name: 'deploy-managed-identity'
  params: {
    identityName: managedIdentityName
    location: location
    tags: tags
  }
}

// =========================================================================
// 2. Key Vault (stores the Teams webhook URL; RBAC-authorized, no access policies)
// =========================================================================
module keyVault '../modules/key-vault.bicep' = {
  name: 'deploy-key-vault'
  params: {
    keyVaultName: keyVaultName
    location: location
    publicNetworkAccessEnabled: keyVaultPublicNetworkAccessEnabled
    softDeleteRetentionInDays: (environmentName == 'prod') ? 90 : 30
    tags: tags
  }
}

resource keyVaultRef 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// Least-privilege: only the alerting Logic App's identity may read secrets.
resource keyVaultSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultRef.id, managedIdentityName, 'KeyVaultSecretsUser')
  scope: keyVaultRef
  properties: {
    principalId: managedIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    description: 'Allows the SecOps alerting Logic App to read the Teams webhook secret.'
  }
  dependsOn: [
    keyVault
  ]
}

// Secret value is supplied via a secure pipeline parameter, never committed to source.
resource teamsWebhookSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (!empty(teamsWebhookUrl)) {
  parent: keyVaultRef
  name: teamsWebhookSecretName
  properties: {
    value: teamsWebhookUrl
    contentType: 'text/plain'
  }
  dependsOn: [
    keyVaultSecretsUserAssignment
  ]
}

// =========================================================================
// 3. Logic App (Teams alerting workflow, secretless - reads KV at runtime via MSI)
// =========================================================================
module logicAppAlerting '../modules/logic-app-alerting.bicep' = if (enableTeamsAlerting) {
  name: 'deploy-logic-app-alerting'
  params: {
    logicAppName: logicAppName
    location: location
    userAssignedIdentityId: managedIdentity.outputs.identityId
    keyVaultUri: keyVault.outputs.keyVaultUri
    teamsWebhookSecretName: teamsWebhookSecretName
    enabled: true
    tags: tags
  }
  dependsOn: [
    keyVaultSecretsUserAssignment
  ]
}

// =========================================================================
// 4. Action Group (fan-out: email + Teams Logic App)
// =========================================================================
module actionGroup '../modules/action-groups.bicep' = {
  name: 'deploy-action-group'
  params: {
    actionGroupName: actionGroupName
    actionGroupShortName: actionGroupShortName
    enabled: true
    emailReceivers: actionGroupEmailReceivers
    logicAppResourceId: enableTeamsAlerting ? resourceId('Microsoft.Logic/workflows', logicAppName) : ''
    logicAppCallbackUrl: enableTeamsAlerting ? listCallbackUrl(resourceId('Microsoft.Logic/workflows/triggers', logicAppName, logicAppTriggerName), '2019-05-01').value : ''
    tags: tags
  }
  dependsOn: [
    logicAppAlerting
  ]
}

// =========================================================================
// 5. Diagnostic settings for platform resources
// =========================================================================
module diagKeyVault '../modules/diagnostic-settings.bicep' = {
  name: 'deploy-diag-keyvault'
  params: {
    targetResourceType: 'KeyVault'
    targetResourceName: keyVault.outputs.keyVaultName
    logAnalyticsWorkspaceId: existingLogAnalyticsWorkspace.id
    diagnosticSettingName: 'diag-to-law'
  }
}

module diagLogicApp '../modules/diagnostic-settings.bicep' = if (enableTeamsAlerting) {
  name: 'deploy-diag-logicapp'
  params: {
    targetResourceType: 'LogicApp'
    targetResourceName: logicAppName
    logAnalyticsWorkspaceId: existingLogAnalyticsWorkspace.id
    diagnosticSettingName: 'diag-to-law'
  }
  dependsOn: [
    logicAppAlerting
  ]
}

// =========================================================================
// 6. Azure Workbooks (Executive / SOC / Zero Trust)
// =========================================================================
module executiveWorkbook '../modules/workbook.bicep' = {
  name: 'deploy-workbook-executive'
  params: {
    workbookId: guid(existingLogAnalyticsWorkspace.id, 'executive-security-dashboard')
    displayName: 'Executive Security Dashboard - ${toUpper(environmentName)}'
    workbookJson: loadTextContent('../workbooks/executive-security-dashboard.json')
    sourceId: existingLogAnalyticsWorkspace.id
    location: location
    tags: tags
  }
}

module socWorkbook '../modules/workbook.bicep' = {
  name: 'deploy-workbook-soc'
  params: {
    workbookId: guid(existingLogAnalyticsWorkspace.id, 'soc-dashboard')
    displayName: 'SOC Dashboard - ${toUpper(environmentName)}'
    workbookJson: loadTextContent('../workbooks/soc-dashboard.json')
    sourceId: existingLogAnalyticsWorkspace.id
    location: location
    tags: tags
  }
}

module zeroTrustWorkbook '../modules/workbook.bicep' = {
  name: 'deploy-workbook-zerotrust'
  params: {
    workbookId: guid(existingLogAnalyticsWorkspace.id, 'zero-trust-dashboard')
    displayName: 'Zero Trust Dashboard - ${toUpper(environmentName)}'
    workbookJson: loadTextContent('../workbooks/zero-trust-dashboard.json')
    sourceId: existingLogAnalyticsWorkspace.id
    location: location
    tags: tags
  }
}

// =========================================================================
// 7. Sentinel Scheduled Analytics Rules (detections)
//
// NOTE: Unlike the workbook KQL in /kql (which uses the {TimeRange} workbook
// macro), Sentinel scheduled rule queries are time-bounded by queryPeriod
// and must not contain workbook-only macro syntax, so these queries embed an
// explicit ago() filter matching queryPeriod instead.
// =========================================================================
var bruteForceQuery = '''
let FailureThreshold = 5;
let LookbackWindow = 30m;
let FailedSignins =
    SigninLogs
    | where TimeGenerated > ago(1h)
    | where ResultType !in ('0', '50125', '50140')
    | summarize FailedAttempts = count(), FailedIPs = make_set(IPAddress, 10), LastFailure = max(TimeGenerated)
        by UserPrincipalName, bin(TimeGenerated, LookbackWindow)
    | where FailedAttempts >= FailureThreshold;
let SuccessfulSignins =
    SigninLogs
    | where TimeGenerated > ago(1h)
    | where ResultType == '0'
    | project UserPrincipalName, SuccessTime = TimeGenerated, SuccessIP = IPAddress;
FailedSignins
| join kind=inner SuccessfulSignins on UserPrincipalName
| where SuccessTime between (LastFailure .. (LastFailure + LookbackWindow))
| project UserPrincipalName, FailedAttempts, FailedIPs, LastFailureTime = LastFailure, SuccessTime, SuccessIP
'''

// NOTE: This platform deliberately does NOT ship an "Impossible Travel"
// scheduled rule, even though kql/identity/impossible-travel.kql exists as a
// hunting query and workbook tile. sufideen/ztr-entra-lz - the Zero Trust
// identity-plane landing zone this dashboard is designed to sit on top of -
// already deploys that exact detection (bicep/modules/sentinel/analyticsRules.bicep,
// rule "Impossible travel sign-in (Zero Trust)"). Duplicating it here would
// create two independent Sentinel rules alerting on the same signal in the
// same workspace. See docs/architecture.md#8-relationship-to-sibling-repositories
// for the full rule/workbook ownership boundary between the two repos.
var oauthConsentGrantQuery = '''
let HighRiskScopes = dynamic([
    'Mail.Read', 'Mail.ReadWrite', 'Mail.Send',
    'Files.ReadWrite.All', 'Sites.ReadWrite.All',
    'Directory.ReadWrite.All', 'RoleManagement.ReadWrite.Directory',
    'MailboxSettings.ReadWrite', 'User.ReadWrite.All'
]);
AuditLogs
| where TimeGenerated > ago(1h)
| where OperationName == 'Consent to application'
| extend AppDisplayName = tostring(TargetResources[0].displayName)
| extend GrantedBy = tostring(InitiatedBy.user.userPrincipalName)
| extend ModifiedProps = TargetResources[0].modifiedProperties
| mv-expand ModifiedProps
| where tostring(ModifiedProps.displayName) in ('ConsentAction.Permissions', 'Scope', 'DelegatedPermissionGrant.Scope')
| extend Scopes = tostring(ModifiedProps.newValue)
| where Scopes has_any (HighRiskScopes)
| project TimeGenerated, AppDisplayName, GrantedBy, Scopes, CorrelationId
'''

var failedSigninSpikeQuery = '''
SigninLogs
| where TimeGenerated > ago(1h)
| where ResultType !in ('0', '50125', '50140')
| summarize FailureCount = count(), DistinctIPs = dcount(IPAddress) by UserPrincipalName
| where FailureCount >= 10
'''

var conditionalAccessFailureSpikeQuery = '''
SigninLogs
| where TimeGenerated > ago(1h)
| mv-expand CA = ConditionalAccessPolicies
| where tostring(CA.result) == 'failure'
| summarize FailureCount = count() by PolicyName = tostring(CA.displayName)
| where FailureCount >= 20
'''

var privilegedRoleChangeQuery = '''
let PrivilegedRoles = dynamic(['Global Administrator','Privileged Role Administrator','Security Administrator']);
AuditLogs
| where TimeGenerated > ago(1h)
| where Category == 'RoleManagement'
| where OperationName == 'Add member to role'
| extend RoleName = tostring(TargetResources[0].modifiedProperties[1].newValue)
| extend TargetUser = tostring(TargetResources[0].userPrincipalName)
| extend InitiatedBy = tostring(InitiatedBy.user.userPrincipalName)
| where RoleName has_any (PrivilegedRoles)
| project TimeGenerated, RoleName, TargetUser, InitiatedBy, Result
'''

module sentinelRules '../modules/sentinel-rules.bicep' = if (enableAnalyticsRules) {
  name: 'deploy-sentinel-analytics-rules'
  // Scopes the entire module - including its internal `existing` LAW
  // reference and the alertRules deployed as extensions on it - to the
  // workspace's own resource group, which may differ from this deployment's
  // resource group (see existingLogAnalyticsWorkspaceResourceGroup).
  scope: resourceGroup(existingLogAnalyticsWorkspaceResourceGroup)
  params: {
    logAnalyticsWorkspaceName: existingLogAnalyticsWorkspaceName
    analyticsRules: [
      {
        ruleIdSeed: 'brute-force-detection-v1'
        displayName: '[SecOps Platform] Brute Force Sign-in Pattern Detected'
        description: 'Detects 5+ failed sign-ins for a user followed by a success within 30 minutes.'
        severity: 'High'
        enabled: true
        query: bruteForceQuery
        queryFrequency: 'PT1H'
        queryPeriod: 'PT1H'
        triggerOperator: 'GreaterThan'
        triggerThreshold: 0
        tactics: [
          'CredentialAccess'
        ]
        techniques: [
          'T1110'
        ]
        suppressionEnabled: false
        suppressionDuration: 'PT1H'
      }
      {
        ruleIdSeed: 'high-risk-oauth-consent-v1'
        displayName: '[SecOps Platform] High-Risk OAuth Consent Grant'
        description: 'Detects consent grants to app registrations requesting high-privilege Graph scopes (mail, files, directory) - a persistence technique that survives password resets and bypasses MFA.'
        severity: 'Medium'
        enabled: true
        query: oauthConsentGrantQuery
        queryFrequency: 'PT1H'
        queryPeriod: 'PT1H'
        triggerOperator: 'GreaterThan'
        triggerThreshold: 0
        tactics: [
          'Persistence'
        ]
        techniques: [
          'T1098'
        ]
        suppressionEnabled: false
        suppressionDuration: 'PT1H'
      }
      {
        ruleIdSeed: 'failed-signin-spike-v1'
        displayName: '[SecOps Platform] Failed Sign-in Spike'
        description: 'Detects a user with 10 or more failed sign-ins in a 1-hour window (password spray / brute force precursor).'
        severity: 'Medium'
        enabled: true
        query: failedSigninSpikeQuery
        queryFrequency: 'PT1H'
        queryPeriod: 'PT1H'
        triggerOperator: 'GreaterThan'
        triggerThreshold: 0
        tactics: [
          'CredentialAccess'
        ]
        techniques: [
          'T1110'
        ]
        suppressionEnabled: false
        suppressionDuration: 'PT1H'
      }
      {
        ruleIdSeed: 'ca-failure-spike-v1'
        displayName: '[SecOps Platform] Conditional Access Failure Spike'
        description: 'Detects a Conditional Access policy failing 20+ times in a 1-hour window, indicating possible probing or misconfiguration.'
        severity: 'Low'
        enabled: true
        query: conditionalAccessFailureSpikeQuery
        queryFrequency: 'PT1H'
        queryPeriod: 'PT1H'
        triggerOperator: 'GreaterThan'
        triggerThreshold: 0
        tactics: [
          'DefenseEvasion'
        ]
        techniques: [
          'T1556'
        ]
        suppressionEnabled: false
        suppressionDuration: 'PT1H'
      }
      {
        ruleIdSeed: 'privileged-role-change-v1'
        displayName: '[SecOps Platform] Privileged Role Assignment'
        description: 'Fires on any addition of a user to a highly privileged Entra ID role (Global Admin, Privileged Role Admin, Security Admin).'
        severity: 'High'
        enabled: true
        query: privilegedRoleChangeQuery
        queryFrequency: 'PT1H'
        queryPeriod: 'PT1H'
        triggerOperator: 'GreaterThan'
        triggerThreshold: 0
        tactics: [
          'PrivilegeEscalation'
          'PersistenceMechanism'
        ]
        techniques: [
          'T1098'
        ]
        suppressionEnabled: false
        suppressionDuration: 'PT1H'
      }
    ]
  }
}

// =========================================================================
// 8. RBAC (least privilege, scoped to the Log Analytics Workspace)
// =========================================================================
module rbac '../modules/rbac.bicep' = {
  name: 'deploy-rbac'
  // Same reasoning as the sentinelRules module above: scope the whole
  // module to the workspace's own resource group, not this deployment's.
  scope: resourceGroup(existingLogAnalyticsWorkspaceResourceGroup)
  params: {
    logAnalyticsWorkspaceName: existingLogAnalyticsWorkspaceName
    roleAssignments: concat(
      !empty(socAnalystsGroupObjectId) ? [
        {
          principalId: socAnalystsGroupObjectId
          principalType: 'Group'
          roleDefinitionId: '3e150937-b8fe-4cfb-8069-0eaf05ecd056' // Microsoft Sentinel Responder
          assignmentNameSeed: 'soc-analysts-sentinel-responder'
        }
        {
          principalId: socAnalystsGroupObjectId
          principalType: 'Group'
          roleDefinitionId: '73c42c96-874c-492b-b04d-ab87d138a893' // Log Analytics Reader
          assignmentNameSeed: 'soc-analysts-log-analytics-reader'
        }
        {
          principalId: socAnalystsGroupObjectId
          principalType: 'Group'
          roleDefinitionId: 'b279062a-9be3-42a0-92ae-8b3cf002ec4d' // Workbook Reader
          assignmentNameSeed: 'soc-analysts-workbook-reader'
        }
      ] : [],
      !empty(securityAdminsGroupObjectId) ? [
        {
          principalId: securityAdminsGroupObjectId
          principalType: 'Group'
          roleDefinitionId: 'ab8e14d6-4a74-4a29-9ba8-549422addade' // Microsoft Sentinel Contributor
          assignmentNameSeed: 'security-admins-sentinel-contributor'
        }
        {
          principalId: securityAdminsGroupObjectId
          principalType: 'Group'
          roleDefinitionId: 'fb1c8493-542b-48eb-b624-b4c8fea62acd' // Security Admin
          assignmentNameSeed: 'security-admins-security-admin'
        }
      ] : [],
      !empty(executivesGroupObjectId) ? [
        {
          principalId: executivesGroupObjectId
          principalType: 'Group'
          roleDefinitionId: '8d289c81-5878-46d4-8554-54e1e3d8b5cb' // Microsoft Sentinel Reader
          assignmentNameSeed: 'executives-sentinel-reader'
        }
        {
          principalId: executivesGroupObjectId
          principalType: 'Group'
          roleDefinitionId: 'b279062a-9be3-42a0-92ae-8b3cf002ec4d' // Workbook Reader
          assignmentNameSeed: 'executives-workbook-reader'
        }
      ] : [],
      !empty(auditorsGroupObjectId) ? [
        {
          principalId: auditorsGroupObjectId
          principalType: 'Group'
          roleDefinitionId: '39bc4728-0917-49c7-9d2c-d95423bc2eb4' // Security Reader
          assignmentNameSeed: 'auditors-security-reader'
        }
        {
          principalId: auditorsGroupObjectId
          principalType: 'Group'
          roleDefinitionId: '73c42c96-874c-492b-b04d-ab87d138a893' // Log Analytics Reader
          assignmentNameSeed: 'auditors-log-analytics-reader'
        }
      ] : []
    )
  }
}

// -----------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------
output keyVaultName string = keyVault.outputs.keyVaultName
output keyVaultUri string = keyVault.outputs.keyVaultUri
output managedIdentityPrincipalId string = managedIdentity.outputs.principalId
output actionGroupId string = actionGroup.outputs.actionGroupId
output workbookIds object = {
  executive: executiveWorkbook.outputs.workbookResourceId
  soc: socWorkbook.outputs.workbookResourceId
  zeroTrust: zeroTrustWorkbook.outputs.workbookResourceId
}
output analyticsRuleIds array = enableAnalyticsRules ? sentinelRules.outputs.ruleResourceIds : []
