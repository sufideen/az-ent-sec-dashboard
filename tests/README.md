# Tests

## Pester (`tests/pester/`)

| File | Type | What it checks |
|---|---|---|
| `Bicep.Lint.Tests.ps1` | Unit | Every `.bicep` file and all 3 `.bicepparam` files compile cleanly with the Bicep CLI |
| `Workbook.Schema.Tests.ps1` | Unit | Workbook JSON structure (required `TimeRange`/`Workspace` parameters) and KQL library header conventions |
| `Deploy.WhatIf.Tests.ps1` | Integration (skipped by default) | Runs `az deployment group what-if` against a real subscription; requires `SECOPS_RG_DEV`/`SECOPS_RG_TEST`/`SECOPS_RG_PROD` env vars and an authenticated `az login` session |

Run everything that doesn't require live Azure connectivity:

```powershell
Install-Module -Name Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force
Invoke-Pester -Path tests/pester/Bicep.Lint.Tests.ps1, tests/pester/Workbook.Schema.Tests.ps1 -Output Detailed
```

Run the full suite including the live integration test:

```powershell
$env:SECOPS_RG_DEV = 'rg-contoso-secops-dev-eus-001'
az login
Invoke-Pester -Path tests/pester/ -Output Detailed
```

## PSRule for Azure (`/ps-rule.yaml`, repo root)

The repo-root [`ps-rule.yaml`](../ps-rule.yaml) configures the [PSRule.Rules.Azure](https://azure.github.io/PSRule.Rules.Azure/) `Azure.Default` baseline against the compiled Bicep output, catching Well-Architected Framework deviations (missing diagnostic settings, public network exposure, missing tags, etc.) that a plain `bicep build` cannot detect. It lives at the repo root — matching `sufideen/securebicep`'s convention — so PSRule's own working-directory auto-discovery picks it up with no `-Option` flag; CI passes it explicitly anyway for clarity.

Use `Assert-PSRule`, not `Invoke-PSRule` — `Assert-PSRule` is the cmdlet meant for CI pass/fail gating (non-zero exit on any Fail-level result); `Invoke-PSRule` just returns results without that gating behavior.

```powershell
Install-Module -Name PSRule.Rules.Azure -Scope CurrentUser -Force
Assert-PSRule -InputPath bicep -Module PSRule.Rules.Azure -Option ps-rule.yaml -Format File
```

## Checkov (`/.checkov.yaml`, repo root)

[`.checkov.yaml`](../.checkov.yaml) configures Checkov's Bicep scan, including one documented `skip-check` (a crash in Checkov's own `KeyVaultDisablesPublicNetworkAccess` check against a parameterized value — see the file's comments) and a note on a known Checkov Bicep-parser limitation against `bicep/main.bicep` that doesn't affect the gate (parsing errors don't fail Checkov's exit code). Convention matches `sufideen/securebicep`.

```bash
pip install checkov
checkov --config-file .checkov.yaml
```

All three (Pester, PSRule, Checkov) are wired into CI — see `pipelines/github/security-scan.yml` / `bicep-lint.yml` and the `SecurityScan` stage in `pipelines/azure-devops/azure-pipelines.yml`.
