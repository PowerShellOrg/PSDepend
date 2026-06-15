#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force
}

Describe 'ConvertFrom-VersionRange' {

    Context 'Exact versions (no delimiters)' {

        It 'Treats a bare version as exact' {
            InModuleScope PSDepend {
                $r = ConvertFrom-VersionRange -Version '3.2.1'
                $r.IsExact | Should -BeTrue
                $r.Exact | Should -Be '3.2.1'
            }
        }

        It 'Treats a bracketed single version as exact' {
            InModuleScope PSDepend {
                $r = ConvertFrom-VersionRange -Version '[1.0]'
                $r.IsExact | Should -BeTrue
                $r.Exact | Should -Be '1.0'
            }
        }
    }

    Context 'Bounded ranges' {

        It 'Parses an inclusive-lower, exclusive-upper range' {
            InModuleScope PSDepend {
                $r = ConvertFrom-VersionRange -Version '[2.2.3,3.0)'
                $r.IsExact | Should -BeFalse
                $r.Min | Should -Be '2.2.3'
                $r.Max | Should -Be '3.0'
                $r.MinInclusive | Should -BeTrue
                $r.MaxInclusive | Should -BeFalse
            }
        }

        It 'Parses an exclusive-lower, inclusive-upper range' {
            InModuleScope PSDepend {
                $r = ConvertFrom-VersionRange -Version '(1.0,2.0]'
                $r.MinInclusive | Should -BeFalse
                $r.MaxInclusive | Should -BeTrue
            }
        }

        It 'Tolerates whitespace around bounds' {
            InModuleScope PSDepend {
                $r = ConvertFrom-VersionRange -Version '[1.0, 2.0]'
                $r.Min | Should -Be '1.0'
                $r.Max | Should -Be '2.0'
            }
        }
    }

    Context 'Open-ended ranges' {

        It 'Parses a minimum-only range' {
            InModuleScope PSDepend {
                $r = ConvertFrom-VersionRange -Version '[2.0,)'
                $r.Min | Should -Be '2.0'
                $r.Max | Should -BeNullOrEmpty
                $r.MinInclusive | Should -BeTrue
            }
        }

        It 'Parses a maximum-only range' {
            InModuleScope PSDepend {
                $r = ConvertFrom-VersionRange -Version '(,3.0)'
                $r.Min | Should -BeNullOrEmpty
                $r.Max | Should -Be '3.0'
                $r.MaxInclusive | Should -BeFalse
            }
        }
    }

    Context 'Malformed ranges' {

        It 'Errors on a missing closing bracket' {
            InModuleScope PSDepend {
                ConvertFrom-VersionRange -Version '[1.0,2.0' -ErrorAction SilentlyContinue
            } | Should -BeNullOrEmpty
        }

        It 'Errors on an empty range' {
            InModuleScope PSDepend {
                ConvertFrom-VersionRange -Version '(,)' -ErrorAction SilentlyContinue
            } | Should -BeNullOrEmpty
        }

        It 'Errors on a parenthesised single version' {
            InModuleScope PSDepend {
                ConvertFrom-VersionRange -Version '(1.0)' -ErrorAction SilentlyContinue
            } | Should -BeNullOrEmpty
        }
    }
}
