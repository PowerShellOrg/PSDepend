#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force
}

Describe 'Test-VersionEquality' {

    Context 'Null and empty inputs' {

        It 'Returns false when ReferenceVersion is empty' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '' -DifferenceVersion '1.0.0'
            } | Should -BeFalse
        }

        It 'Returns false when DifferenceVersion is empty' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '1.0.0' -DifferenceVersion ''
            } | Should -BeFalse
        }

        It 'Returns false when both are empty' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '' -DifferenceVersion ''
            } | Should -BeFalse
        }
    }

    Context '[System.Version] two-part (Major.Minor)' {

        It 'Returns true for identical two-part versions' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '1.2' -DifferenceVersion '1.2'
            } | Should -BeTrue
        }

        It 'Returns false when minor differs' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '1.2' -DifferenceVersion '1.3'
            } | Should -BeFalse
        }

        It 'Returns false when major differs' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '1.0' -DifferenceVersion '2.0'
            } | Should -BeFalse
        }
    }

    Context '[System.Version] three-part (Major.Minor.Build)' {

        It 'Returns true for identical three-part versions' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '1.2.3' -DifferenceVersion '1.2.3'
            } | Should -BeTrue
        }

        It 'Returns true when both omit build (treated as 0)' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '1.2.0' -DifferenceVersion '1.2'
            } | Should -BeTrue
        }

        It 'Returns false when build differs' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '1.2.3' -DifferenceVersion '1.2.4'
            } | Should -BeFalse
        }
    }

    Context '[System.Version] four-part (Major.Minor.Build.Revision)' {

        It 'Returns true for identical four-part versions' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '1.2.3.4' -DifferenceVersion '1.2.3.4'
            } | Should -BeTrue
        }

        It 'Returns true when revision is absent on one side (treated as 0)' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '1.2.3.0' -DifferenceVersion '1.2.3'
            } | Should -BeTrue
        }

        It 'Returns false when revision differs' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '1.2.3.4' -DifferenceVersion '1.2.3.5'
            } | Should -BeFalse
        }
    }

    Context 'SemanticVersion (Major.Minor.Patch[-pre[+build]])' {

        It 'Returns true for identical semver strings' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '1.2.3' -DifferenceVersion '1.2.3'
            } | Should -BeTrue
        }

        It 'Returns true for identical semver with pre-release label' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '2.0.0-beta.1' -DifferenceVersion '2.0.0-beta.1'
            } | Should -BeTrue
        }

        It 'Returns false when patch differs' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '1.2.3' -DifferenceVersion '1.2.4'
            } | Should -BeFalse
        }

        It 'Returns false when pre-release label differs' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '2.0.0-alpha' -DifferenceVersion '2.0.0-beta'
            } | Should -BeFalse
        }

        It 'Returns false when one has a pre-release label and the other does not' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '2.0.0-beta' -DifferenceVersion '2.0.0'
            } | Should -BeFalse
        }
    }

    Context 'Tricky versions with zero components or zero-prefixed pre-release' {

        # 0.0.0.5 — [System.Version] Build=0 Revision=5
        # Risk: Math.Max(Build,0) normalises absent build (-1) to 0,
        # so 0.0.0.5 must NOT equal 0.0.0 even though both have Build→0 after normalisation.
        It 'Returns true for 0.0.0.5 equal to itself' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '0.0.0.5' -DifferenceVersion '0.0.0.5'
            } | Should -BeTrue
        }

        It 'Returns false for 0.0.0.5 vs 0.0.0 (revision 5 vs absent)' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '0.0.0.5' -DifferenceVersion '0.0.0'
            } | Should -BeFalse
        }

        It 'Returns false for 0.0.0.5 vs 0.0.0.4' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '0.0.0.5' -DifferenceVersion '0.0.0.4'
            } | Should -BeFalse
        }

        # 0.1.0.2 — [System.Version] Build=0 Revision=2; same zero-build concern
        It 'Returns true for 0.1.0.2 equal to itself' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '0.1.0.2' -DifferenceVersion '0.1.0.2'
            } | Should -BeTrue
        }

        It 'Returns false for 0.1.0.2 vs 0.1.0 (revision 2 vs absent)' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '0.1.0.2' -DifferenceVersion '0.1.0'
            } | Should -BeFalse
        }

        # 1.0.2-0alpha.5 — SemanticVersion path; pre-release starts with digit 0
        # (valid because the identifier is alphanumeric, not purely numeric)
        It 'Returns true for 1.0.2-0alpha.5 equal to itself' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '1.0.2-0alpha.5' -DifferenceVersion '1.0.2-0alpha.5'
            } | Should -BeTrue
        }

        It 'Returns false for 1.0.2-0alpha.5 vs 1.0.2 (pre-release vs none)' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '1.0.2-0alpha.5' -DifferenceVersion '1.0.2'
            } | Should -BeFalse
        }

        It 'Returns false for 1.0.2-0alpha.5 vs 1.0.2-0alpha.6 (differing pre-release suffix)' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '1.0.2-0alpha.5' -DifferenceVersion '1.0.2-0alpha.6'
            } | Should -BeFalse
        }
    }

    Context 'CalVer and arbitrary string fallback' {

        It 'Returns true for identical CalVer strings' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '2024.01.15' -DifferenceVersion '2024.01.15'
            } | Should -BeTrue
        }

        It 'Returns false for different CalVer strings' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion '2024.01.15' -DifferenceVersion '2024.02.01'
            } | Should -BeFalse
        }

        It 'Returns true for identical arbitrary version strings' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion 'latest' -DifferenceVersion 'latest'
            } | Should -BeTrue
        }

        It 'Returns false for different arbitrary strings' {
            InModuleScope PSDepend {
                Test-VersionEquality -ReferenceVersion 'latest' -DifferenceVersion 'stable'
            } | Should -BeFalse
        }
    }
}
