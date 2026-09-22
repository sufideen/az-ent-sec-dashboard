# Azure Security Operations Platform

[![Bicep Lint](https://github.com/sufideen/az-ent-sec-dashboard/actions/workflows/bicep-lint.yml/badge.svg)](https://github.com/sufideen/az-ent-sec-dashboard/actions/workflows/bicep-lint.yml)
[![Security Scan](https://github.com/sufideen/az-ent-sec-dashboard/actions/workflows/security-scan.yml/badge.svg)](https://github.com/sufideen/az-ent-sec-dashboard/actions/workflows/security-scan.yml)
[![IaC: Bicep](https://img.shields.io/badge/IaC-Bicep-0078d4)](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/overview)
[![Auth: OIDC](https://img.shields.io/badge/Auth-OIDC%20Passwordless-107c10)](https://learn.microsoft.com/en-us/azure/active-directory/workload-identities/workload-identity-federation)
[![Secrets: Zero in source](https://img.shields.io/badge/Secrets-Zero%20in%20source-critical)](docs/architecture.md)

Enterprise Security Operations Dashboard for Azure, deployed entirely via Bicep. This platform sits **on top of** an already-deployed security foundation — Microsoft Sentinel, a centralized Log Analytics Workspace, Entra ID integrated with Sentinel, Zero Trust architecture, Azure Policy, and Defender for Cloud — and adds the executive, SOC, and Zero Trust reporting layer plus a curated detection and alerting pack.

## Part of a layered Azure security platform

This is layer 3 of a 3-repo stack, not a standalone project — each repo owns a distinct scope, and none duplicate each other's Sentinel content (see [architecture.md #8](docs/architecture.md#8-relationship-to-sibling-repositories) for the full rule-by-rule boundary):

| Layer | Repo | Scope | Owns |
|---|---|---|---|
| 1. Foundation | [`azl-bicepdeploy`](https://github.com/sufideen/azl-bicepdeploy) | tenant / mgmt-group / subscription | Management groups, Azure Policy, the Log Analytics Workspace itself |
| 2. Identity / Zero Trust plane | [`ztr-entra-lz`](https://github.com/sufideen/ztr-entra-lz) | subscription | Conditional Access, PIM, custom RBAC roles, identity-plane Sentinel rules, ISO 27001 compliance-evidence workbook |
| 3. **This repo** | `az-ent-sec-dashboard` | resource group | Executive/SOC/Zero Trust operational dashboards, complementary detection rules, Teams/email alerting |

CI/CD gating conventions (Checkov + PSRule as hard merge gates, root-level `.checkov.yaml`/`ps-rule.yaml`, OIDC-only deploy credentials) are shared with [`securebicep`](https://github.com/sufideen/securebicep), the account's dedicated DevSecOps-pipeline reference.

## What this repository deploys

| Capability | Implementation |
|---|---|
| Executive Security Dashboard | Azure Workbook: Secure Score, incidents, MTTD/MTTR, compliance, trends |
| SOC Dashboard | Azure Workbook: active incidents, alert severity, MITRE ATT&CK, TI matches |
| Zero Trust Dashboard | Azure Workbook: MFA adoption, CA success rate, risky users, PIM, device compliance, guests |
| Detections | 5 Microsoft Sentinel Scheduled Analytics Rules (brute force, high-risk OAuth consent, sign-in/CA failure spikes, privileged role changes) — chosen to complement, not duplicate, `ztr-entra-lz`'s identity-plane rules |
| Alerting | Azure Monitor Action Group -> Logic App -> Microsoft Teams (secretless: Key Vault + Managed Identity) + email |
| Access control | Least-privilege RBAC scoped to the Log Analytics Workspace for SOC/Security Admin/Executive/Auditor Entra ID groups |
| Observability | Diagnostic settings for all platform-owned resources -> the existing Log Analytics Workspace |

## What this repository does **not** deploy

Sentinel itself, the Log Analytics Workspace, Defender for Cloud, Entra ID Conditional Access policies, or Azure Policy assignments — these are assumed to already exist per the environment this platform targets, deployed by `azl-bicepdeploy` and `ztr-entra-lz` above. `bicep/main.bicep` references the workspace as an `existing` resource.

## Secure AKS web platform (`webplat`)

A second, self-contained workload also lives in this repo: a private AKS
cluster + private ACR + Application Gateway (WAF_v2) ingress for hosting a
company website, with a working Nginx demo app and GitHub Actions CI/CD
(OIDC, no stored secrets). It's independent of the secops platform above —
see [`docs/webplat-architecture.md`](docs/webplat-architecture.md) for the
full design, administrator runbook, security checklist, and teardown
procedure.

**New to this project?** Start with
[`docs/kubernetes-showcase.md`](docs/kubernetes-showcase.md) — a
portfolio-oriented walkthrough (architecture, cluster breakdown, glossary,
use cases, real incident, evidence, and a
[slide deck](docs/webplat-kubernetes-showcase.pdf), also as [PowerPoint](docs/webplat-kubernetes-showcase.pptx)) built for a technical
reviewer who wants the story, not just the file tree.

**Design documentation**, split by audience:
- [`docs/hld-webplat.md`](docs/hld-webplat.md) — High-Level Design for
  architects/reviewers: system context, logical and network architecture
  (with [SVG diagrams](docs/diagrams/)), key design decisions and
  trade-offs, non-functional requirements
- [`docs/lld-webplat-operations.md`](docs/lld-webplat-operations.md) —
  Low-Level Design for the Azure admin/support team: exact resource
  inventory, the identity/RBAC matrix, day-2 procedures, and a
  troubleshooting playbook built from real incidents on this platform

> **Lab environments.** These are lab deployments used to demonstrate the design. Public IP addresses in the evidence files are replaced with documentation-range addresses (`203.0.113.x`), and the environments may be torn down when not in use.

**Status** (as of 2026-09-22): both environments were fully torn down
(resource groups deleted) after the initial demo cycle, per
[Tearing down an environment](docs/webplat-architecture.md#tearing-down-an-environment).
**Dev has since been rebuilt from scratch and re-verified end-to-end** —
nodes `Ready`, `demo-web` pods `Running`, App Gateway backend pool
`Healthy`, and `curl` through the public ingress returns the real app over
HTTPS at `dev-webplat.ict-cloud.solutions`. **Prod is not yet redeployed.**

Rebuilding from a full teardown surfaced a second class of incident beyond
the original SecretProviderClass bug (see
[Incident: prod SecretProviderClass](docs/webplat-architecture.md#incident-prod-secretproviderclass-never-patched)):
several pieces of platform state don't come back automatically when a
resource group is deleted and recreated, even though the Bicep/Kustomize
source is unchanged —
- RBAC role assignments (ARM-level *and* Kubernetes-level Azure RBAC) are
  scoped to the resource and are deleted with it; they need re-granting to
  the GitHub Actions service principal, admin users, and the AKS Key Vault
  CSI managed identity
- The Key Vault Secrets Provider add-on gets a **new** managed identity
  client ID every time AKS is rebuilt, so any Kustomize overlay that
  hardcodes `userAssignedIdentityID` goes stale and needs updating
  ([`k8s/overlays/dev/kustomization.yaml`](k8s/overlays/dev/kustomization.yaml))
- Key Vaults are soft-deleted (purge-protected), so a same-named vault has
  to be recovered, not recreated
- A shared dependency (the Log Analytics Workspace referenced by
  `existingLogAnalyticsWorkspaceName`/`ResourceGroup`) can itself be
  renamed or removed outside this repo's control
- App Gateway gets a new public IP on rebuild, so any external DNS record
  pointing at the old IP goes stale

None of this is captured in Bicep/Kustomize today — it's manual `az` cleanup
after a teardown-and-rebuild. See
[`docs/lld-webplat-operations.md`](docs/lld-webplat-operations.md) for the
day-2 operations playbook this session's fixes should be folded into.
See [`docs/screenshots/webplat/`](docs/screenshots/webplat/) for the
evidence checklist and captured output from the original verified deploy.

## Repository structure

```
azure-security-operations-platform/
├── .checkov.yaml               # Checkov config (root, matches sufideen/securebicep convention)
├── ps-rule.yaml                 # PSRule for Azure config (root, auto-discovered)
├── bicep/
│   ├── main.bicep                # Orchestrator template
│   └── params/                   # Per-environment parameter files
│       ├── dev.bicepparam
│       ├── test.bicepparam
│       └── prod.bicepparam
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
└── tests/                      # Pester tests (PSRule/Checkov configs live at repo root)
```

## Quick start

```bash
# 1. Lint & build
az bicep build --file bicep/main.bicep

# 2. Preview changes (What-If)
az deployment group what-if \
  --resource-group rg-itsolutions-secops-dev-eus-001 \
  --template-file bicep/main.bicep \
  --parameters bicep/params/dev.bicepparam

# 3. Deploy
az deployment group create \
  --resource-group rg-itsolutions-secops-dev-eus-001 \
  --template-file bicep/main.bicep \
  --parameters bicep/params/dev.bicepparam \
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

- **CAF naming**: `<resource-type>-<workload>-<environment>-<region>-<instance>`, e.g. `logic-itsolutions-secops-prod-eus-001`.
- **Zero Trust / least privilege**: RBAC is scoped directly to the Log Analytics Workspace, not the subscription; the alerting Logic App holds zero secrets and reads Key Vault at runtime via a user-assigned managed identity.
- **No secrets in source control**: the Teams webhook URL is a `@secure()` Bicep parameter supplied by a pipeline secret variable and stored only in Key Vault.
- **No placeholders**: every module and the orchestrator have been compiled with the Bicep CLI (`az bicep build`) as part of authoring this repository; parameter files build cleanly for all three environments.
- **Well-Architected Framework**: cost (Log Analytics tiered pricing, workbook queries are unbilled reads), operational excellence (CI/CD with What-If + security scanning), reliability (Consumption Logic App with managed retries), security (RBAC, Key Vault, MSI, private networking by default outside dev).

## License

Internal reference architecture. Adapt naming, RBAC group IDs, and cost assumptions to your tenant before deploying.

## Reproduce it from scratch

1. **Prerequisites:** an Azure subscription (this creates billable resources, so use a
   sandbox and set a budget alert), the Azure CLI with Bicep, and a GitHub fork of this
   repo. Permissions needed are listed in the deployment steps above.
2. **Configure OIDC:** create an Entra app registration with a federated credential for
   your fork, then add its IDs as repository secrets (names are in the workflow files).
   No passwords or keys are required.
3. **Validate first:** open a pull request or run the workflow manually. The what-if step
   shows what would be created without changing anything.
4. **Deploy:** run the deployment as described in this README, then check the
   verification steps and screenshots to confirm the result matches.
5. **Tear down** the resources when finished to stop charges.

If any step here does not work as written, please open an issue. That is a documentation
bug.
