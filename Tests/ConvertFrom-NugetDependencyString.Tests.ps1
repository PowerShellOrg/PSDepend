#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force
}

Describe 'ConvertFrom-NugetDependencyString' {

    Context 'Empty input' {

        It 'Returns an empty hashtable for null' {
            InModuleScope PSDepend {
                $r = ConvertFrom-NugetDependencyString -Dependencies $null
                $r | Should -BeOfType [hashtable]
                $r.Count | Should -Be 0
            }
        }

        It 'Returns an empty hashtable for an empty string' {
            InModuleScope PSDepend {
                $r = ConvertFrom-NugetDependencyString -Dependencies ''
                $r | Should -BeOfType [hashtable]
                $r.Count | Should -Be 0
            }
        }
    }

    Context 'Range conversion' {

        It 'Converts a bare version to a minimum-inclusive range' {
            InModuleScope PSDepend {
                $r = ConvertFrom-NugetDependencyString -Dependencies 'Newtonsoft.Json:13.0.1:'
                $r.Count | Should -Be 1
                $r['Newtonsoft.Json'] | Should -Be '[13.0.1,)'
            }
        }

        It 'Maps an empty range to latest' {
            InModuleScope PSDepend {
                $r = ConvertFrom-NugetDependencyString -Dependencies 'Foo::'
                $r['Foo'] | Should -Be 'latest'
            }
        }

        It 'Keeps a bracketed range and strips internal whitespace' {
            InModuleScope PSDepend {
                $r = ConvertFrom-NugetDependencyString -Dependencies 'chocolatey-core.extension:[1.3.3, ):'
                $r['chocolatey-core.extension'] | Should -Be '[1.3.3,)'
            }
        }

        It 'Keeps a bracketed exact version' {
            InModuleScope PSDepend {
                $r = ConvertFrom-NugetDependencyString -Dependencies 'git.install:[2.44.0]:'
                $r['git.install'] | Should -Be '[2.44.0]'
            }
        }

        It 'Keeps an upper-bound-only range' {
            InModuleScope PSDepend {
                $r = ConvertFrom-NugetDependencyString -Dependencies 'Bar:(,3.0]:net45'
                $r['Bar'] | Should -Be '(,3.0]'
            }
        }
    }

    Context 'Entries and frameworks' {

        It 'Parses a mixed multi-entry string and skips framework-only groups' {
            InModuleScope PSDepend {
                $r = ConvertFrom-NugetDependencyString -Dependencies 'git.install:[2.44.0]:|chocolatey-core.extension:[1.3.3, ):|Foo::|::net45'
                $r.Count | Should -Be 3
                $r['git.install'] | Should -Be '[2.44.0]'
                $r['chocolatey-core.extension'] | Should -Be '[1.3.3,)'
                $r['Foo'] | Should -Be 'latest'
            }
        }

        It 'Keeps the first occurrence when an id appears under several frameworks' {
            InModuleScope PSDepend {
                $r = ConvertFrom-NugetDependencyString -Dependencies 'Foo:1.0.0:net45|Foo:2.0.0:netstandard2.0'
                $r.Count | Should -Be 1
                $r['Foo'] | Should -Be '[1.0.0,)'
            }
        }

        It 'Handles an entry with no framework segment' {
            InModuleScope PSDepend {
                $r = ConvertFrom-NugetDependencyString -Dependencies 'Foo:1.0.0'
                $r['Foo'] | Should -Be '[1.0.0,)'
            }
        }
    }
}
