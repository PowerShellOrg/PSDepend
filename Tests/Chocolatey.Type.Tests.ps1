# cspell:ignore feedpass feeduser
#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force
    $script:SkipUnsupported = -not (Test-PSDependTypeSupportedHere -DependencyType 'Chocolatey')
}

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/Chocolatey.ps1'
}

Describe 'Chocolatey script' -Tag 'WindowsOnly' -Skip:$SkipUnsupported {

    BeforeAll {
        InModuleScope PSDepend {
            # Pretend choco.exe is present so we skip the bootstrap branch
            Mock Get-Command { [PSCustomObject]@{ Name = 'choco.exe' } } -ParameterFilter { $Name -eq 'choco.exe' }
            # All choco invocations return empty CSV (no packages installed, none found upstream)
            Mock Invoke-ExternalCommand { }
            Mock Invoke-WebRequest { }
        }
    }

    It 'Defaults Source to https://community.chocolatey.org/api/v2/ when not supplied' {
        $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey'
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -Force
        }
        Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
            ($Arguments -join ' ') -match "--source='https://community\.chocolatey\.org/api/v2/'"
        }
    }

    It 'Passes --yes to choco upgrade to suppress interactive prompts' {
        $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version '2.0.2'
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -Force
        }
        Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
            $Arguments -contains 'upgrade' -and $Arguments -contains '--yes'
        }
    }

    It 'Invokes choco upgrade with -Force when -Force switch is set' {
        $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version '2.0.2'
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -Force
        }
        Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
            $Arguments -contains 'upgrade' -and $Arguments -contains '--force'
        }
    }

    It 'Forwards Credential to choco as --username / --password args' {
        $cred = New-TestCredential -UserName 'feeduser' -Password 'feedpass'
        $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version '2.0.2' -Credential $cred
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -Force
        }
        Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
            ($Arguments -join ' ') -match "--username='feeduser'" -and ($Arguments -join ' ') -match "--password='feedpass'"
        }
    }

    Context 'NuGet version ranges' {
        It 'Installs the highest available version that satisfies the range' {
            $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version '[2.0.0,3.0.0)'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                Mock Invoke-ExternalCommand {
                    'git|1.9.0'
                    'git|2.5.0'
                    'git|3.0.0'
                } -ParameterFilter { $Arguments -contains '--all-versions' }

                & $ScriptPath -Dependency $Dep
            }
            Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
                $Arguments -contains 'upgrade' -and $Arguments -contains "--version='2.5.0'"
            }
        }

        It 'Resolves a range before a forced installation' {
            $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version '[2.0.0,3.0.0)'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                Mock Invoke-ExternalCommand {
                    'git|2.4.0'
                    'git|2.8.0'
                } -ParameterFilter { $Arguments -contains '--all-versions' }

                & $ScriptPath -Dependency $Dep -Force
            }
            Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
                $Arguments -contains 'upgrade' -and
                $Arguments -contains "--version='2.8.0'" -and
                $Arguments -contains '--force'
            }
        }

        It 'Accepts an installed version that satisfies the range' {
            $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version '[2.0.0,3.0.0)'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                Mock Invoke-ExternalCommand { 'git|2.4.0' } -ParameterFilter { $Arguments -contains 'list' }

                & $ScriptPath -Dependency $Dep -PSDependAction Test
            } | Should -BeTrue
            Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 0 -Exactly -ParameterFilter {
                $Arguments -contains 'search'
            }
        }

        It 'Skips installation when no available version satisfies the range' {
            $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version '[2.0.0,3.0.0)'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                Mock Invoke-ExternalCommand { 'git|1.9.0' } -ParameterFilter { $Arguments -contains '--all-versions' }

                & $ScriptPath -Dependency $Dep -ErrorAction SilentlyContinue
            }
            Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 0 -Exactly -ParameterFilter {
                $Arguments -contains 'upgrade'
            }
        }

        It 'Skips installation for a malformed range' {
            $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version '[2.0.0,3.0.0'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -ErrorAction SilentlyContinue
            }
            Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 0 -Exactly -ParameterFilter {
                $Arguments -contains 'upgrade'
            }
        }
    }
}
