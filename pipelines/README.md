# Pipelines

## GitHub Actions (`github/`)

These files are the canonical source and are also mirrored to `.github/workflows/` at the repository root, because GitHub Actions only executes workflows physically located under `.github/workflows/`. When editing a workflow, update both copies (or replace `.github/workflows/` with symlinks back to this directory in your fork).

| File | Trigger | Purpose |
|---|---|---|
| `bicep-lint.yml` | PR + push to `main` | `az bicep build` on the orchestrator + every module; validates all 3 `.bicepparam` files and workbook JSON |
| `security-scan.yml` | PR + push to `main` | Microsoft Security DevOps, Checkov, Gitleaks, PSRule for Azure |
| `what-if.yml` | PR | `az deployment group what-if` for dev/test/prod, posts a summary comment |
| `deploy.yml` | Push to `main` (+ manual dispatch) | Deploys Dev automatically, then Test, then Prod - Test/Prod gated by GitHub Environment required reviewers |

## Azure DevOps (`azure-devops/`)

`azure-pipelines.yml` implements the same six logical stages as a single multi-stage YAML pipeline: `Validate -> SecurityScan -> WhatIf -> DeployDev -> DeployTest -> DeployProd`. See [docs/deployment-guide.md](../docs/deployment-guide.md) for the service connection, environment, and variable group setup required before first run.
