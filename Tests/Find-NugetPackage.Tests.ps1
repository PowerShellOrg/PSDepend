#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force
}

Describe 'Find-NugetPackage' {
    It 'Reads every OData page when all package versions are requested' {
        InModuleScope PSDepend {
            function New-FeedEntry {
                param([string]$Version)

                [PSCustomObject]@{
                    title      = [PSCustomObject]@{ '#text' = 'Example' }
                    author     = [PSCustomObject]@{ name = 'Author' }
                    Content    = [PSCustomObject]@{ src = "https://example.test/$Version" }
                    properties = [PSCustomObject]@{
                        NormalizedVersion = $Version
                        Description       = 'Example package'
                    }
                }
            }

            Mock Invoke-RestMethod {
                if ($Uri -match '\$skip=100') {
                    return New-FeedEntry -Version '101.0.0'
                }
                if ($Uri -match '\$skip=101') {
                    return
                }
                1..100 | ForEach-Object { New-FeedEntry -Version "$_.0.0" }
            }

            $result = @(Find-NugetPackage -Name 'Example' -PackageSourceUrl 'https://example.test/api/v2/')

            $result.Count | Should -Be 101
            $result[-1].Version | Should -Be '101.0.0'
            Should -Invoke Invoke-RestMethod -Times 3 -Exactly -ParameterFilter {
                $Uri -match '\$top=100&\$skip=(0|100|101)$'
            }
        }
    }

    It 'Uses one request for an exact version' {
        InModuleScope PSDepend {
            Mock Invoke-RestMethod { @() }

            $null = Find-NugetPackage -Name 'Example' -Version '1.2.3'

            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                $Uri -notmatch '\$top=' -and $Uri -notmatch '\$skip='
            }
        }
    }
}
