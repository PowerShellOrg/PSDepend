#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force
}

Describe 'Compare-Version' {

    Context 'SemanticVersion ordering' {

        It 'Returns 0 for equal three-part versions' {
            InModuleScope PSDepend {
                Compare-Version -ReferenceVersion '1.2.3' -DifferenceVersion '1.2.3'
            } | Should -Be 0
        }

        It 'Returns -1 when reference is lower' {
            InModuleScope PSDepend {
                Compare-Version -ReferenceVersion '1.2.0' -DifferenceVersion '1.2.3'
            } | Should -Be -1
        }

        It 'Returns 1 when reference is higher' {
            InModuleScope PSDepend {
                Compare-Version -ReferenceVersion '2.0.0' -DifferenceVersion '1.9.9'
            } | Should -Be 1
        }

        It 'Orders a pre-release below its release' {
            InModuleScope PSDepend {
                Compare-Version -ReferenceVersion '1.0.0-alpha' -DifferenceVersion '1.0.0'
            } | Should -Be -1
        }

        It 'Orders pre-release labels lexically' {
            InModuleScope PSDepend {
                Compare-Version -ReferenceVersion '2.0.0-beta' -DifferenceVersion '2.0.0-alpha'
            } | Should -Be 1
        }
    }

    Context 'System.Version fallback and normalisation' {

        It 'Compares four-part versions SemVer rejects' {
            InModuleScope PSDepend {
                Compare-Version -ReferenceVersion '1.2.3.4' -DifferenceVersion '1.2.3.5'
            } | Should -Be -1
        }

        It 'Treats absent build/revision as zero' {
            InModuleScope PSDepend {
                Compare-Version -ReferenceVersion '1.2.3.0' -DifferenceVersion '1.2.3'
            } | Should -Be 0
        }

        It 'Distinguishes a non-zero revision from an absent one' {
            InModuleScope PSDepend {
                Compare-Version -ReferenceVersion '0.0.0.5' -DifferenceVersion '0.0.0'
            } | Should -Be 1
        }
    }

    Context 'String fallback' {

        It 'Returns 0 for identical unparseable strings' {
            InModuleScope PSDepend {
                Compare-Version -ReferenceVersion 'latest' -DifferenceVersion 'latest'
            } | Should -Be 0
        }

        It 'Returns non-zero for different unparseable strings' {
            InModuleScope PSDepend {
                Compare-Version -ReferenceVersion 'latest' -DifferenceVersion 'stable'
            } | Should -Not -Be 0
        }
    }
}
