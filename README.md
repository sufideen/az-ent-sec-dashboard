# Azure Security Operations Platform

Enterprise Security Operations Dashboard for Azure, deployed entirely via Bicep. This platform sits **on top of** an already-deployed security foundation — Microsoft Sentinel, a centralized Log Analytics Workspace, Entra ID integrated with Sentinel, Zero Trust architecture, Azure Policy, and Defender for Cloud — and adds the executive, SOC, and Zero Trust reporting layer plus a curated detection and alerting pack.

## What this repository deploys

| Capability | Implementation |
|---|---|
| Executive Security Dashboard | Azure Workbook: Secure Score, incidents, MTTD/MTTR, compliance, trends |
| SOC Dashboard | Azure Workbook: active incidents, alert severity, MITRE ATT&CK, TI matches |
| Zero Trust Dashboard | Azure Workbook: MFA adoption, CA success rate, risky users, PIM, device compliance, guests |
| Detections | 5 Microsoft Sentinel Scheduled Analytics Rules (brute force, impossible travel, sign-in spikes, CA failure spikes, privileged role changes) |
| Alerting | Azure Monitor Action Group -> Logic App -> Microsoft Teams (secretless: Key Vault + Managed Identity) + email |
| Access control | Least-privilege RBAC scoped to the Log Analytics Workspace for SOC/Security Admin/Executive/Auditor Entra ID groups |
| Observability | Diagnostic settings for all platform-owned resources -> the existing Log Analytics Workspace |

## What this repository does **not** deploy

Sentinel itself, the Log Analytics Workspace, Defender for Cloud, Entra ID Conditional Access policies, or Azure Policy assignments — these are assumed to already exist per the environment this platform targets. `bicep/main.bicep` references the workspace as an `existing` resource.

## Repository structure

```
azure-security-operations-platform/
├── bicep/                    # Orchestrator template + per-environment parameter files
│   ├── main.bicep
│   ├── main.dev.bicepparam
│   ├── main.test.bicepparam
│   └── main.prod.bicepparam
├── modules/                  # Reusable Bicep modules (CAF-compliant naming)
│   ├── workbook.bicep
│   ├── sentinel-rules.bicep
│   ├── diagnostic-settings.bicep
│   ├── action-groups.bicep
│   ├── logic-app-alerting.bicep
│   ├── rbac.bicep
│   ├── key-vault.bicep
│   └── managed-identity.bicep
├── workbooks/                 # Azure Workbook JSON definitions (deployed by workbook.bicep)
│   ├── executive-security-dashboard.json
│   ├── soc-dashboard.json
│   └── zero-trust-dashboard.json
├── kql/                       # Production-ready KQL library (SOC hunting + workbook source queries)
│   ├── incidents/
│   ├── identity/
│   ├── defender/
│   ├── compliance/
│   └── threat-intel/
├── pipelines/
│   ├── github/                # GitHub Actions workflows (mirrored into .github/workflows/)
│   └── azure-devops/          # Azure DevOps YAML pipeline
├── docs/                       # Architecture, deployment, runbooks, cost, roadmap
└── tests/                      # Pester + PSRule for Azure validation
```

## Quick start

```bash
# 1. Lint & build
az bicep build --file bicep/main.bicep

# 2. Preview changes (What-If)
az deployment group what-if \
  --resource-group rg-contoso-secops-dev-eus-001 \
  --template-file bicep/main.bicep \
  --parameters bicep/main.dev.bicepparam

# 3. Deploy
az deployment group create \
  --resource-group rg-contoso-secops-dev-eus-001 \
  --template-file bicep/main.bicep \
  --parameters bicep/main.dev.bicepparam \
  --parameters teamsWebhookUrl="$TEAMS_WEBHOOK_URL_DEV"
```

See [docs/deployment-guide.md](docs/deployment-guide.md) for the full walkthrough, prerequisites, and CI/CD setup.

## Documentation

- [Architecture Guide](docs/architecture.md) — component diagram, data flow, design decisions
- [Deployment Guide](docs/deployment-guide.md) — prerequisites, parameters, CI/CD wiring
- [Runbook](docs/runbook.md) — day-2 operations (rotate secrets, add a rule, update a workbook)
- [Incident Response Guide](docs/incident-response-guide.md) — using this platform during an active incident
- [SOC Operations Guide](docs/soc-operations-guide.md) — daily/weekly SOC analyst workflow
- [Executive Reporting Guide](docs/executive-reporting-guide.md) — reading and presenting the Executive dashboard
- [Cost Estimates](docs/cost-estimates.md) — Small/Medium/Large monthly cost breakdowns
- [Roadmap](docs/roadmap.md) — implementation phases
- [Production Readiness Checklist](docs/production-readiness-checklist.md)

## Design principles

- **CAF naming**: `<resource-type>-<workload>-<environment>-<region>-<instance>`, e.g. `logic-contoso-secops-prod-eus-001`.
- **Zero Trust / least privilege**: RBAC is scoped directly to the Log Analytics Workspace, not the subscription; the alerting Logic App holds zero secrets and reads Key Vault at runtime via a user-assigned managed identity.
- **No secrets in source control**: the Teams webhook URL is a `@secure()` Bicep parameter supplied by a pipeline secret variable and stored only in Key Vault.
- **No placeholders**: every module and the orchestrator have been compiled with the Bicep CLI (`az bicep build`) as part of authoring this repository; parameter files build cleanly for all three environments.
- **Well-Architected Framework**: cost (Log Analytics tiered pricing, workbook queries are unbilled reads), operational excellence (CI/CD with What-If + security scanning), reliability (Consumption Logic App with managed retries), security (RBAC, Key Vault, MSI, private networking by default outside dev).

## License

Internal reference architecture. Adapt naming, RBAC group IDs, and cost assumptions to your tenant before deploying.
