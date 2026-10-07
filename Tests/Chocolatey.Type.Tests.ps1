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

        It 'Passes a bracketed exact range as a concrete version' {
            $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version '[2.0.0]'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -Force
            }
            Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
                $Arguments -contains 'upgrade' -and $Arguments -contains "--version='2.0.0'"
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

        It 'Returns false when no available version satisfies the range during testing' {
            $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version '[2.0.0,3.0.0)'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                Mock Invoke-ExternalCommand { 'git|1.9.0' } -ParameterFilter { $Arguments -contains '--all-versions' }

                & $ScriptPath -Dependency $Dep -PSDependAction Test -ErrorAction SilentlyContinue
            } | Should -BeFalse
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

# Resolve queries the NuGet v2 feed directly and never needs choco.exe, so it runs on every platform.
Describe 'Chocolatey script Resolve' {

    BeforeAll {
        $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/Chocolatey.ps1'
        InModuleScope PSDepend {
            Mock Invoke-ExternalCommand { }
            Mock Find-NugetPackage {
                foreach ($entry in @(
                        @{ Version = '2.44.0'; Dependencies = 'git.install:[2.44.0]:|chocolatey-core.extension:[1.3.3, ):|:'; IsPrerelease = 'false' },
                        @{ Version = '2.45.0'; Dependencies = 'git.install:[2.45.0]:'; IsPrerelease = 'false' },
                        @{ Version = '2.46.0-beta1'; Dependencies = ''; IsPrerelease = 'true' },
                        @{ Version = '3.0.0'; Dependencies = 'git.install:3.0.0:|::'; IsPrerelease = 'false' }
                    )) {
                    [PSCustomObject]@{
                        Name       = 'git'
                        Version    = $entry.Version
                        Properties = [PSCustomObject]@{
                            Dependencies = $entry.Dependencies
                            IsPrerelease = $entry.IsPrerelease
                        }
                    }
                }
            }
        }
    }

    Context 'PSDependAction = Resolve' {

        It 'Latest picks the highest stable version and skips prerelease' {
            $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version 'latest'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Resolve
            }
            $result.PSTypeNames | Should -Contain 'PSDepend.ResolvedDependency'
            $result.Name | Should -Be 'git'
            $result.Version | Should -Be '3.0.0'
        }

        It 'Range picks the highest stable in-range version, skipping prerelease' {
            $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version '[2.0.0,3.0.0)'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Resolve
            }
            $result.Version | Should -Be '2.45.0'
        }

        It 'Converts the feed Dependencies string to a NuGet-range map' {
            $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version '2.44.0'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Resolve
            }
            $result.Version | Should -Be '2.44.0'
            $result.Dependencies | Should -BeOfType [hashtable]
            $result.Dependencies.Count | Should -Be 2
            $result.Dependencies['git.install'] | Should -Be '[2.44.0]'
            $result.Dependencies['chocolatey-core.extension'] | Should -Be '[1.3.3,)'
        }

        It 'Converts a bare dependency version to a minimum-inclusive range' {
            $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version '3.0.0'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Resolve
            }
            $result.Dependencies.Count | Should -Be 1
            $result.Dependencies['git.install'] | Should -Be '[3.0.0,)'
        }

        It 'Writes an error and emits nothing when no version satisfies' {
            $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version '[4.0.0,)'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Resolve -ErrorAction SilentlyContinue -ErrorVariable err
                $err | Should -Not -BeNullOrEmpty
                $err[0].ToString() | Should -Match 'No version of \[git\] at \[https://community\.chocolatey\.org/api/v2/\] satisfies \[\[4\.0\.0,\)\]'
            }
            $result | Should -BeNullOrEmpty
        }

        It 'Writes an error and emits nothing when Source is not a feed URL' {
            $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Source 'C:\LocalFeed'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Resolve -ErrorAction SilentlyContinue -ErrorVariable err
                $err[0].ToString() | Should -Match 'NuGet v2 feed URL'
            }
            $result | Should -BeNullOrEmpty
            Should -Invoke -CommandName Find-NugetPackage -ModuleName PSDepend -Times 0 -Exactly
        }

        It 'Rejects an HTTP source when credentials would be transmitted' {
            $credential = New-TestCredential -UserName 'feeduser' -Password 'feedpass'
            $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' `
                -Source 'http://packages.example.test/api/v2/' -Credential $credential

            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Resolve -ErrorAction SilentlyContinue -ErrorVariable err
                $err[0].ToString() | Should -Match 'requires an HTTPS Source'
            }

            $result | Should -BeNullOrEmpty
            Should -Invoke -CommandName Find-NugetPackage -ModuleName PSDepend -Times 0 -Exactly
        }

        It 'Never invokes choco during Resolve' {
            $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version 'latest'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Resolve
            }
            Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 0 -Exactly
            Should -Invoke -CommandName Find-NugetPackage -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
                $PackageSourceUrl -eq 'https://community.chocolatey.org/api/v2/'
            }
        }
    }
}
