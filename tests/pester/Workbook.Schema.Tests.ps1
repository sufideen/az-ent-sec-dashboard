<#
.SYNOPSIS
    Validates the structural integrity of the Azure Workbook JSON definitions
    and the KQL query library.

.NOTES
    Run with: Invoke-Pester -Path tests/pester/Workbook.Schema.Tests.ps1
#>

BeforeAll {
    $RepoRoot = Resolve-Path "$PSScriptRoot/../.."
    $WorkbooksDir = Join-Path $RepoRoot 'workbooks'
    $KqlDir = Join-Path $RepoRoot 'kql'

    $script:ExpectedWorkbooks = @(
        'executive-security-dashboard.json'
        'soc-dashboard.json'
        'zero-trust-dashboard.json'
    )
}

Describe 'Workbook JSON definitions' {

    It 'expected workbook file <_> exists' -TestCases ($script:ExpectedWorkbooks | ForEach-Object { @{ _ = $_ } }) {
        param($_)
        Test-Path (Join-Path $WorkbooksDir $_) | Should -BeTrue
    }

    It '<_> is valid JSON with required top-level keys' -TestCases ($script:ExpectedWorkbooks | ForEach-Object { @{ _ = $_ } }) {
        param($_)
        $path = Join-Path $WorkbooksDir $_
        $json = Get-Content $path -Raw | ConvertFrom-Json

        $json.version | Should -Be 'Notebook/1.0'
        $json.items | Should -Not -BeNullOrEmpty
        $json.items.Count | Should -BeGreaterThan 0
    }

    It '<_> contains a parameters step with TimeRange and Workspace' -TestCases ($script:ExpectedWorkbooks | ForEach-Object { @{ _ = $_ } }) {
        param($_)
        $path = Join-Path $WorkbooksDir $_
        $json = Get-Content $path -Raw | ConvertFrom-Json

        $paramItems = $json.items | Where-Object { $_.type -eq 9 }
        $paramItems.Count | Should -BeGreaterThan 0

        $paramNames = $paramItems[0].content.parameters | ForEach-Object { $_.name }
        $paramNames | Should -Contain 'TimeRange'
        $paramNames | Should -Contain 'Workspace'
    }
}

Describe 'KQL query library' {

    It 'kql directory has the 5 expected category folders' {
        $expected = @('incidents', 'identity', 'defender', 'compliance', 'threat-intel')
        $actual = Get-ChildItem -Path $KqlDir -Directory | Select-Object -ExpandProperty Name
        foreach ($category in $expected) {
            $actual | Should -Contain $category
        }
    }

    It 'every .kql file has a non-empty header comment block' {
        $kqlFiles = Get-ChildItem -Path $KqlDir -Recurse -Filter '*.kql'
        $kqlFiles.Count | Should -BeGreaterThan 0

        foreach ($file in $kqlFiles) {
            $content = Get-Content $file.FullName -Raw
            $content | Should -Match '// Query:' -Because "$($file.Name) is missing a '// Query:' header"
            $content | Should -Match '// (Table|Engine)' -Because "$($file.Name) is missing a data-source reference ('// Table:' or '// Engine:')"
        }
    }
}
