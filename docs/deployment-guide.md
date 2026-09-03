# Deployment Guide

## Prerequisites

1. **Existing infrastructure** (see repo root README): Microsoft Sentinel enabled on a Log Analytics Workspace, Defender for Cloud, Entra ID, Azure Policy.
2. **Permissions** to deploy: `Contributor` + `User Access Administrator` (or `Owner`) on the target resource group, since the template creates RBAC role assignments.
3. **Tooling**: Azure CLI >= 2.60, Bicep CLI >= 0.30 (`az bicep install`).
4. **Entra ID groups** for the four personas (SOC Analysts, Security Admins, Executives, Auditors) — capture their object IDs for the parameter files.
5. **A resource group** that either contains the existing Log Analytics Workspace, or is peered/near it (cross-RG is supported via `existingLogAnalyticsWorkspaceResourceGroup`).

## Parameters you must set per environment

Edit `bicep/params/<env>.bicepparam`:

| Parameter | Required | Notes |
|---|---|---|
| `existingLogAnalyticsWorkspaceName` | Yes | Must already exist with Sentinel enabled |
| `existingLogAnalyticsWorkspaceResourceGroup` | Yes | Defaults to the deployment RG |
| `orgPrefix` | Yes | 2-10 chars, e.g. `contoso` |
| `actionGroupEmailReceivers` | Yes | At least the SOC distribution list |
| `socAnalystsGroupObjectId` / `securityAdminsGroupObjectId` / `executivesGroupObjectId` / `auditorsGroupObjectId` | Recommended | Leave blank to skip that persona's RBAC (module handles empty gracefully) |
| `teamsWebhookUrl` | No (secure) | **Never** hard-code — pass via `--parameters teamsWebhookUrl=$(SECRET)` from a pipeline secret / Key Vault-backed variable group |
| `keyVaultPublicNetworkAccessEnabled` | No | Defaults `true` for dev, `false` for test/prod (pair with a Private Endpoint in test/prod) |

## Manual deployment

```bash
az login
az account set --subscription "<subscription-id>"

# Lint
az bicep build --file bicep/main.bicep

# What-If (always run before create)
az deployment group what-if \
  --resource-group rg-contoso-secops-dev-eus-001 \
  --template-file bicep/main.bicep \
  --parameters bicep/params/dev.bicepparam

# Deploy
az deployment group create \
  --name secops-platform-dev-$(date +%Y%m%d%H%M) \
  --resource-group rg-contoso-secops-dev-eus-001 \
  --template-file bicep/main.bicep \
  --parameters bicep/params/dev.bicepparam \
  --parameters teamsWebhookUrl="$TEAMS_WEBHOOK_URL_DEV"
```

Repeat for `test` and `prod`, changing the parameter file and resource group.

## CI/CD deployment

### GitHub Actions

1. Copy/keep in sync: `pipelines/github/*.yml` <-> `.github/workflows/*.yml` (both are checked into this repo; `.github/workflows/` is what GitHub actually executes).
2. Configure federated OIDC credentials for a service principal (no client secrets): `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` repository secrets.
3. Configure repository variables: `RESOURCE_GROUP_DEV`, `RESOURCE_GROUP_TEST`, `RESOURCE_GROUP_PROD`.
4. Configure repository secrets: `TEAMS_WEBHOOK_URL_DEV/TEST/PROD`.
5. Create GitHub **Environments** named `dev`, `test`, `production`. Add **required reviewers** to `test` and `production` — this is the "Deployment Approval" gate; `deploy.yml`'s `environment:` key enforces it automatically.
6. Order of workflows on every PR: `bicep-lint.yml` -> `security-scan.yml` -> `what-if.yml`. On merge to `main`: `deploy.yml` runs Dev automatically, then waits for environment approval before Test and Prod.

### Azure DevOps

1. Import `pipelines/azure-devops/azure-pipelines.yml` as a new pipeline pointing at this repo.
2. Create ARM service connections `arm-secops-dev`, `arm-secops-test`, `arm-secops-prod` using workload-identity federation.
3. Create Environments `secops-dev`, `secops-test`, `secops-prod` under Pipelines > Environments. Add **Approvals and checks** (required approvers) to `secops-test` and `secops-prod`.
4. Create variable group `secops-alerting-secrets` (link to Key Vault) with `TeamsWebhookUrlDev`, `TeamsWebhookUrlTest`, `TeamsWebhookUrlProd`.
5. Stages run in order: `Validate -> SecurityScan -> WhatIf -> DeployDev -> DeployTest -> DeployProd`, each gated on the prior stage succeeding, with Test/Prod additionally gated on manual approval.

## Branch protection strategy

- `main` is protected: require a pull request, require at least 1 approving review, dismiss stale approvals on new commits, disallow force-push and branch deletion.
- **Owner sign-off**: `.github/CODEOWNERS` names `@sufideen` as owner of the entire repository, so every PR automatically requests their review. This only becomes a hard gate once **"Require review from Code Owners"** is also turned on under Settings > Branches > Branch protection rules > `main` — CODEOWNERS alone requests the review but does not by itself block merging without that setting enabled. Neither GitHub's REST/GraphQL API nor the MCP GitHub server used by this workflow exposes a branch-protection-write endpoint in this environment, so this one setting has to be applied by hand, once, by someone with admin rights on the repo (`sufideen` or an org owner).
- Required status checks — GitHub evaluates required checks at the **job** level, not the workflow name, so select each of these individually under Settings > Branches > Branch protection rules > `main` (they only appear in the picker after each workflow has run at least once on the repo):
  - From `bicep-lint.yml`: `lint`
  - From `security-scan.yml`: `microsoft-security-devops`, `checkov`, `gitleaks`, `psrule`
  - From `what-if.yml`: `what-if` (all three matrix legs: dev, test, prod)
- Each of the four `security-scan.yml` jobs fails closed on findings by default: Checkov runs with `soft_fail: false`, Microsoft Security DevOps and the `microsoft/ps-rule` action both fail their step on any error/fail-level result, and Gitleaks fails on any detected secret. Selecting them as required checks (above) is what turns that into an actual merge gate — without that branch-protection step, the jobs still run and report to code scanning, but a red job would not block the merge button.
- The Azure DevOps pipeline enforces the equivalent gate structurally rather than via a picker: `SecurityScan` (Microsoft Security DevOps + Checkov + PSRule, all failing closed) is a hard `dependsOn` of `WhatIf`, which is a hard `dependsOn` of every `Deploy*` stage — a failure anywhere in `SecurityScan` blocks the rest of the pipeline automatically.
- No direct pushes to `main` — all changes (including parameter file updates) go through PR + What-If review.
- Tag releases (`v1.0.0`, etc.) on `main` after a successful Prod deployment for traceability/rollback reference.

## Populating the Teams webhook secret

The Bicep template never contains a real webhook URL. First deployment can set `enableTeamsAlerting = false` (already the default in `bicep/params/dev.bicepparam`) to stand up the Key Vault and Logic App shell without a working Teams integration, then:

```bash
az keyvault secret set \
  --vault-name <kv-name-from-deployment-output> \
  --name teams-webhook-url \
  --value "https://<tenant>.webhook.office.com/webhookb2/..."
```

...or supply `teamsWebhookUrl` as a secure deployment parameter from a pipeline secret variable on a subsequent deployment with `enableTeamsAlerting = true`.

## Diagnostic settings at scale

This repo's `diagnostic-settings.bicep` module covers the platform's own resources only (see [architecture.md](architecture.md#5-why-diagnostic-settings-for-azure-resources-is-not-a-generic-bicep-module)). To route diagnostics from the broader resource estate into the same Log Analytics Workspace, assign the built-in Azure Policy initiative **"Enable Azure Monitor for resources"** / individual **"Deploy Diagnostic Settings to Log Analytics workspace"** policies (per resource type) at the management-group or subscription scope, targeting the same workspace ID used in `existingLogAnalyticsWorkspaceName`. This is a one-time Azure Policy assignment, not a per-deployment Bicep step.

## Rollback

Bicep deployments are idempotent and incremental by default (`deploymentMode: Incremental`). To roll back:

```bash
az deployment group create \
  --resource-group <rg> \
  --template-file bicep/main.bicep \
  --parameters bicep/params/<env>.bicepparam \
  --rollback-on-error <previous-successful-deployment-name>
```

Or redeploy the previous git tag's `bicep/` directory — since resources are declaratively defined, redeploying an older version reverts drift.
