#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force
}

Describe 'Join-VersionRange' {

    Context 'Unconstrained input' {
        It 'Returns latest when every constraint is empty or latest' {
            InModuleScope PSDepend {
                Join-VersionRange -Range 'latest', '', $null | Should -Be 'latest'
            }
        }

        It 'Ignores latest alongside a real range' {
            InModuleScope PSDepend {
                Join-VersionRange -Range 'latest', '[1.0,2.0)' | Should -Be '[1.0,2.0)'
            }
        }
    }

    Context 'Intersection of ranges' {
        It 'Takes the tightest lower and upper bounds' {
            InModuleScope PSDepend {
                Join-VersionRange -Range '[1.0,3.0)', '[2.0,)' | Should -Be '[2.0,3.0)'
            }
        }

        It 'Prefers the exclusive bound when bounds are equal' {
            InModuleScope PSDepend {
                Join-VersionRange -Range '[1.0,3.0]', '(1.0,3.0)' | Should -Be '(1.0,3.0)'
            }
        }

        It 'Collapses equal inclusive bounds to an exact version' {
            InModuleScope PSDepend {
                Join-VersionRange -Range '[2.0,)', '(,2.0]' | Should -Be '2.0'
            }
        }

        It 'Keeps an open upper bound when no constraint caps it' {
            InModuleScope PSDepend {
                Join-VersionRange -Range '[1.0,)', '[1.5,)' | Should -Be '[1.5,)'
            }
        }
    }

    Context 'Exact versions' {
        It 'Returns the exact version when it lies inside every range' {
            InModuleScope PSDepend {
                Join-VersionRange -Range '2.5.0', '[2.0,3.0)' | Should -Be '2.5.0'
            }
        }

        It 'Accepts two equal exact versions' {
            InModuleScope PSDepend {
                Join-VersionRange -Range '2.5.0', '2.5.0' | Should -Be '2.5.0'
            }
        }
    }

    Context 'Conflicts' {
        It 'Errors when an exact version falls outside a range' {
            InModuleScope PSDepend {
                $result = Join-VersionRange -Range '3.5.0', '[2.0,3.0)' -ErrorAction SilentlyContinue -ErrorVariable err
                $result | Should -BeNullOrEmpty
                $err[0].ToString() | Should -Match 'conflict'
            }
        }

        It 'Errors when two exact versions differ' {
            InModuleScope PSDepend {
                $result = Join-VersionRange -Range '1.0.0', '1.0.1' -ErrorAction SilentlyContinue -ErrorVariable err
                $result | Should -BeNullOrEmpty
                $err | Should -Not -BeNullOrEmpty
            }
        }

        It 'Errors when ranges do not overlap' {
            InModuleScope PSDepend {
                $result = Join-VersionRange -Range '[1.0,2.0)', '[2.0,3.0)' -ErrorAction SilentlyContinue -ErrorVariable err
                $result | Should -BeNullOrEmpty
                $err | Should -Not -BeNullOrEmpty
            }
        }

        It 'Errors when equal bounds meet with an exclusive side' {
            InModuleScope PSDepend {
                $result = Join-VersionRange -Range '[1.0,2.0]', '(2.0,3.0)' -ErrorAction SilentlyContinue -ErrorVariable err
                $result | Should -BeNullOrEmpty
                $err | Should -Not -BeNullOrEmpty
            }
        }
    }
}
