<#
.SYNOPSIS
    Runs `az deployment group what-if` against a live subscription for each
    environment and asserts the operation completes without error.

.DESCRIPTION
    This is an INTEGRATION test - it requires:
      - An authenticated `az login` session (or AZURE_* env vars for a service principal)
      - Environment variables SECOPS_RG_DEV / SECOPS_RG_TEST / SECOPS_RG_PROD naming
        real, existing resource groups that already contain (or are configured to
        reference) a Log Analytics Workspace with Sentinel enabled.
    It is skipped automatically (not failed) when those resource group
    environment variables are not set, so `Invoke-Pester` remains safe to run
    in a sandbox with no Azure connectivity - see Bicep.Lint.Tests.ps1 and
    Workbook.Schema.Tests.ps1 for the tests that always run.

.NOTES
    Run with: Invoke-Pester -Path tests/pester/Deploy.WhatIf.Tests.ps1
#>

BeforeAll {
    $RepoRoot = Resolve-Path "$PSScriptRoot/../.."
    $BicepEntry = Join-Path $RepoRoot 'bicep/main.bicep'

    $script:EnvironmentRgMap = @{
        dev  = $env:SECOPS_RG_DEV
        test = $env:SECOPS_RG_TEST
        prod = $env:SECOPS_RG_PROD
    }
}

Describe 'What-If deployment (integration)' {

    It 'what-if succeeds for <Environment>' -TestCases @(
        @{ Environment = 'dev' }
        @{ Environment = 'test' }
        @{ Environment = 'prod' }
    ) {
        param($Environment)

        $rg = $script:EnvironmentRgMap[$Environment]
        if ([string]::IsNullOrWhiteSpace($rg)) {
            Set-ItResult -Skipped -Because "SECOPS_RG_$($Environment.ToUpper()) is not set - integration test requires a live subscription"
            return
        }

        $paramFile = Join-Path $RepoRoot "bicep/main.$Environment.bicepparam"
        $output = az deployment group what-if `
            --resource-group $rg `
            --template-file $BicepEntry `
            --parameters $paramFile `
            --result-format ResourceIdOnly 2>&1

        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }
}
