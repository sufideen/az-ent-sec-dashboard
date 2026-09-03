<#
.SYNOPSIS
    Validates that every Bicep file in the repository compiles cleanly.

.DESCRIPTION
    Runs `az bicep build` against bicep/main.bicep and every module in
    /modules, failing the test if the Bicep CLI reports any error-level
    diagnostic. Requires the Azure CLI with the Bicep extension installed
    (`az bicep install`).

.NOTES
    Run with: Invoke-Pester -Path tests/pester/Bicep.Lint.Tests.ps1
#>

BeforeAll {
    $RepoRoot = Resolve-Path "$PSScriptRoot/../.."
    $BicepEntry = Join-Path $RepoRoot 'bicep/main.bicep'
    $ModulesDir = Join-Path $RepoRoot 'modules'
}

Describe 'Bicep compilation' {

    It 'az bicep CLI is available' {
        $version = az bicep version 2>$null
        $version | Should -Not -BeNullOrEmpty
    }

    It 'bicep/main.bicep builds without error' {
        $output = az bicep build --file $BicepEntry --stdout 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }

    It 'every module in /modules builds without error' -TestCases (
        Get-ChildItem -Path $ModulesDir -Filter '*.bicep' | ForEach-Object { @{ File = $_.FullName; Name = $_.Name } }
    ) {
        param($File, $Name)
        $output = az bicep build --file $File --stdout 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "Module '$Name' failed to compile: $($output -join "`n")"
    }
}

Describe 'Bicep parameter files' {

    It 'main.<Environment>.bicepparam builds for every supported environment' -TestCases @(
        @{ Environment = 'dev' }
        @{ Environment = 'test' }
        @{ Environment = 'prod' }
    ) {
        param($Environment)
        $paramFile = Join-Path $RepoRoot "bicep/main.$Environment.bicepparam"
        Test-Path $paramFile | Should -BeTrue

        $outFile = Join-Path ([System.IO.Path]::GetTempPath()) "main.$Environment.parameters.json"
        $output = az bicep build-params --file $paramFile --outfile $outFile 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
        Test-Path $outFile | Should -BeTrue
    }
}
