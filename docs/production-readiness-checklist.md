# Production Readiness Checklist

## Infrastructure as Code

- [x] All resources defined in Bicep, no manual/portal-only configuration required
- [x] `az bicep build` passes with zero errors on `bicep/main.bicep` and every file in `/modules`
- [x] All three `bicep/params/*.bicepparam` files build successfully (`az bicep build-params`)
- [x] No hard-coded secrets in any `.bicep`, `.bicepparam`, or `.json` file (Teams webhook is a `@secure()` parameter, never a literal)
- [x] Environment-specific behavior (retention, network access, alerting) is parameterized, not hard-coded
- [ ] `az deployment group what-if` reviewed and approved for the target subscription (run once against real infrastructure before first production apply)

## Security

- [x] RBAC role assignments follow least privilege, scoped to the Log Analytics Workspace (not subscription-wide)
- [x] Alerting Logic App uses a user-assigned Managed Identity — zero embedded credentials
- [x] Key Vault uses RBAC authorization (not access policies), soft-delete + purge protection enabled
- [x] Key Vault defaults to `publicNetworkAccess: Disabled` in test/prod
- [ ] Private Endpoint deployed for the Key Vault in test/prod (not included in this repo's default module call — add per your network topology)
- [ ] Conditional Access policies reviewed to ensure the personas (SOC/SecAdmin/Exec/Auditor) are subject to phishing-resistant MFA
- [ ] `security-scan.yml` / `SecurityScan` stage passing with zero HIGH/CRITICAL findings

## CI/CD

- [x] Validate -> SecurityScan -> WhatIf -> Deploy pipeline defined for both GitHub Actions and Azure DevOps
- [x] Branch protection strategy documented (deployment-guide.md)
- [ ] Branch protection actually configured on `main` in the live repository
- [ ] Environment approval gates actually configured for `test`/`production` (GitHub Environments or ADO Environment checks)
- [ ] Service connections / OIDC federated credentials configured with least-privilege scope (target RG only, not subscription Owner)

## Observability

- [x] Diagnostic settings deployed for all platform-owned resources (Key Vault, Logic App)
- [x] 5 Scheduled Analytics Rules deployed with MITRE ATT&CK tagging
- [ ] Alert fatigue reviewed after 2+ weeks of production data; thresholds tuned per runbook.md
- [ ] On-call rotation and escalation path documented and linked from incident-response-guide.md

## Cost

- [x] Small/Medium/Large cost estimates documented with explicit assumptions
- [ ] Actual first-month spend reconciled against estimates; commitment tier evaluated if applicable
- [ ] Budget alert configured on the subscription/resource group (outside this repo's scope — standard Azure Cost Management)

## Documentation

- [x] README, architecture, deployment, runbook, incident response, SOC ops, executive reporting guides all present
- [x] Every KQL query documented with purpose, source table, and required parameters
- [ ] SOC/Executive/Security Admin teams have completed a walkthrough of their respective guide

## Testing

- [x] Pester test scaffolding validates parameter file structure and required outputs
- [x] PSRule for Azure baseline configured for ongoing CI enforcement
- [ ] Full deployment tested end-to-end in a real Dev subscription (not just `what-if`)

## Sign-off

| Role | Reviewed | Date |
|---|---|---|
| Security Architect | ☐ | |
| DevSecOps Lead | ☐ | |
| SOC Manager | ☐ | |
| CISO | ☐ | |
