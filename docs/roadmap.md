# Implementation Roadmap

## Phase 0 — Prerequisites (before this repo's first deployment)

- [ ] Confirm Sentinel is enabled on the target Log Analytics Workspace
- [ ] Confirm Entra ID data connector (SigninLogs, AuditLogs, AADRiskyUsers, AADUserRiskEvents, AADUserRegistrationDetails) is connected
- [ ] Confirm Defender for Cloud data connector is connected (SecurityRecommendation, SecureScores, SecureScoreControls)
- [ ] Create the four Entra ID groups: SOC Analysts, Security Admins, Executives, Auditors
- [ ] Identify/create the resource group this platform deploys into

## Phase 1 — Foundation (Dev)

- [ ] Deploy `bicep/main.dev.bicepparam` with `enableTeamsAlerting = false`
- [ ] Validate Key Vault, Managed Identity, and RBAC assignments landed correctly
- [ ] Populate the Teams webhook secret; redeploy with `enableTeamsAlerting = true`
- [ ] Send a test alert end-to-end (see runbook.md)
- [ ] Confirm all 3 workbooks render with live data

## Phase 2 — Detection tuning (Dev -> Test)

- [ ] Run all 5 Scheduled Analytics Rules for 1-2 weeks in Dev; tune `triggerThreshold`/`suppressionDuration` against false-positive rate
- [ ] Promote to Test via CI/CD; validate What-If output matches intent
- [ ] SOC team dry-run: use soc-operations-guide.md workflow against Test incidents

## Phase 3 — Production rollout

- [ ] Configure GitHub/Azure DevOps environment approval gates for Prod
- [ ] Deploy to Prod with `keyVaultPublicNetworkAccessEnabled = false` + Private Endpoint
- [ ] Executive walkthrough of the Executive Dashboard (executive-reporting-guide.md)
- [ ] Publish the runbook + incident response guide to the SOC's on-call documentation

## Phase 4 — Scale & optimize (ongoing)

- [ ] Review cost-estimates.md actuals vs. projections after first full month; evaluate Sentinel commitment tier
- [ ] Expand analytics rule pack based on MITRE ATT&CK coverage gaps identified in weekly SOC review
- [ ] Consider Sentinel Automation Rules / Playbooks for auto-remediation of high-confidence, low-risk detections (e.g. auto-disable a confirmed-compromised account)
- [ ] Evaluate Basic Logs / Auxiliary Logs tier for high-volume, low-investigative-value tables to control long-term retention cost
- [ ] Extend diagnostic settings coverage via Azure Policy DeployIfNotExists (see architecture.md) as new resource types are onboarded

## Phase 5 — Continuous improvement

- [ ] Quarterly review of RBAC group membership vs. actual personnel (least-privilege audit)
- [ ] Quarterly review of Secure Score trend + top open compliance findings with the CISO
- [ ] Annual tabletop exercise using incident-response-guide.md against a simulated Sentinel incident
