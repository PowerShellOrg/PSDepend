#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force
}

Describe 'Test-VersionInRange' {

    Context 'Null and empty inputs' {

        It 'Returns false when Version is empty' {
            InModuleScope PSDepend {
                Test-VersionInRange -Version '' -Required '[1.0,2.0)'
            } | Should -BeFalse
        }

        It 'Returns false when Required is empty' {
            InModuleScope PSDepend {
                Test-VersionInRange -Version '1.0.0' -Required ''
            } | Should -BeFalse
        }
    }

    Context 'Exact requests' {

        It 'Returns true for a matching exact version' {
            InModuleScope PSDepend {
                Test-VersionInRange -Version '3.2.1' -Required '3.2.1'
            } | Should -BeTrue
        }

        It 'Returns false for a non-matching exact version' {
            InModuleScope PSDepend {
                Test-VersionInRange -Version '3.2.0' -Required '3.2.1'
            } | Should -BeFalse
        }
    }

    Context 'Bounded ranges' {

        It 'Returns true inside the range' {
            InModuleScope PSDepend {
                Test-VersionInRange -Version '2.5.0' -Required '[2.2.3,3.0)'
            } | Should -BeTrue
        }

        It 'Honours an inclusive lower bound' {
            InModuleScope PSDepend {
                Test-VersionInRange -Version '2.2.3' -Required '[2.2.3,3.0)'
            } | Should -BeTrue
        }

        It 'Honours an exclusive upper bound' {
            InModuleScope PSDepend {
                Test-VersionInRange -Version '3.0.0' -Required '[2.2.3,3.0)'
            } | Should -BeFalse
        }

        It 'Returns false below the range' {
            InModuleScope PSDepend {
                Test-VersionInRange -Version '2.2.2' -Required '[2.2.3,3.0)'
            } | Should -BeFalse
        }

        It 'Honours an exclusive lower bound' {
            InModuleScope PSDepend {
                Test-VersionInRange -Version '1.0.0' -Required '(1.0.0,2.0.0]'
            } | Should -BeFalse
        }
    }

    Context 'Open-ended ranges' {

        It 'Returns true at or above a minimum-only range' {
            InModuleScope PSDepend {
                Test-VersionInRange -Version '5.0.0' -Required '[2.0,)'
            } | Should -BeTrue
        }

        It 'Returns false below a minimum-only range' {
            InModuleScope PSDepend {
                Test-VersionInRange -Version '1.5.0' -Required '[2.0,)'
            } | Should -BeFalse
        }

        It 'Returns true below a maximum-only range' {
            InModuleScope PSDepend {
                Test-VersionInRange -Version '2.9.0' -Required '(,3.0)'
            } | Should -BeTrue
        }
    }

    Context 'Malformed request' {

        It 'Returns false for a malformed range' {
            InModuleScope PSDepend {
                Test-VersionInRange -Version '1.0.0' -Required '[1.0,2.0'
            } | Should -BeFalse
        }
    }
}
