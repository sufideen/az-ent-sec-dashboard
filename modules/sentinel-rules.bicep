// ============================================================================
// Module: sentinel-rules.bicep
// Purpose: Deploy Microsoft Sentinel Scheduled Analytics Rules as extension
// resources on the existing Log Analytics Workspace. Accepts an array of
// rule definitions so the same module deploys the full rule pack from
// main.bicep (KQL sourced from /kql for consistency between the workbook
// dashboards and the detections that feed Sentinel incidents).
// ============================================================================

@description('Name of the existing Log Analytics Workspace with Microsoft Sentinel enabled. This module must be invoked with `scope: resourceGroup(<workspace-resource-group>)` by its caller when the workspace lives in a different resource group than the parent deployment - see bicep/main.bicep.')
param logAnalyticsWorkspaceName string

@description('''
Array of Scheduled Analytics Rule definitions. Each item:
{
  ruleIdSeed: string            // stable seed used to derive a deterministic GUID name
  displayName: string
  description: string
  severity: 'Informational' | 'Low' | 'Medium' | 'High'
  enabled: bool
  query: string                 // KQL
  queryFrequency: string        // ISO8601 duration, e.g. PT1H
  queryPeriod: string           // ISO8601 duration, e.g. PT1H
  triggerOperator: 'GreaterThan' | 'FewerThan' | 'Equal' | 'NotEqual'
  triggerThreshold: int
  tactics: string[]             // MITRE ATT&CK tactics
  techniques: string[]          // MITRE ATT&CK technique IDs, e.g. T1110
  suppressionEnabled: bool
  suppressionDuration: string   // ISO8601 duration
}
''')
param analyticsRules array = []

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource scheduledRules 'Microsoft.SecurityInsights/alertRules@2023-11-01' = [
  for rule in analyticsRules: {
    name: guid(logAnalyticsWorkspace.id, rule.ruleIdSeed)
    scope: logAnalyticsWorkspace
    kind: 'Scheduled'
    properties: {
      displayName: rule.displayName
      description: rule.description
      severity: rule.severity
      enabled: rule.enabled
      query: rule.query
      queryFrequency: rule.queryFrequency
      queryPeriod: rule.queryPeriod
      triggerOperator: rule.triggerOperator
      triggerThreshold: rule.triggerThreshold
      tactics: rule.tactics
      techniques: rule.techniques
      suppressionEnabled: rule.suppressionEnabled
      suppressionDuration: rule.suppressionDuration
      incidentConfiguration: {
        createIncident: true
        // Grouping disabled: each alert becomes its own incident. Azure
        // rejects matchingMethod: 'Selected' unless at least one
        // groupByEntities/groupByAlertDetails/groupByCustomDetails entry is
        // provided (verified against a live deployment) - since every rule
        // here already collapses to one alert per query result via
        // eventGroupingSettings.aggregationKind: 'SingleAlert', there is
        // nothing meaningful to group across, so disabling is correct
        // rather than inventing a groupBy field just to satisfy validation.
        groupingConfiguration: {
          enabled: false
          reopenClosedIncident: false
          // Unused while enabled: false, but Bicep's type schema for
          // GroupingConfiguration marks these required regardless (flagged
          // by the compiler itself as a possible schema inaccuracy, BCP035)
          // - supplied to satisfy that rather than gamble on whether the
          // live API agrees. 'AnyAlert' needs no groupBy* fields.
          lookbackDuration: 'PT5H'
          matchingMethod: 'AnyAlert'
        }
      }
      eventGroupingSettings: {
        aggregationKind: 'SingleAlert'
      }
      alertRuleTemplateName: null
    }
  }
]

output ruleResourceIds array = [for i in range(0, length(analyticsRules)): scheduledRules[i].id]
output ruleNames array = [for i in range(0, length(analyticsRules)): scheduledRules[i].name]
