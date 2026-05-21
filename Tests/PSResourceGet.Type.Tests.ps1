#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/PSResourceGet.ps1'
    $script:TestCred   = New-TestCredential
    $script:OrigPSModulePath = $env:PSModulePath
}

AfterAll {
    if ($script:OrigPSModulePath) {
        $env:PSModulePath = $script:OrigPSModulePath
    }
}

Describe 'PSResourceGet script' {

    BeforeAll {
        InModuleScope PSDepend {
            # Stubs for PSResourceGet cmdlets — needed so Pester can mock them on machines where
            # Microsoft.PowerShell.PSResourceGet is not installed. Parameter declarations must
            # match what PSResourceGet.ps1 passes so the param-stripping loop keeps them intact.
            function Get-PSResourceRepository {
                [CmdletBinding()] param([string]$Name)
            }
            function Find-PSResource {
                [CmdletBinding()] param(
                    [string]$Name, [string]$Repository,
                    [PSCredential]$Credential, [switch]$Prerelease
                )
            }
            function Install-PSResource {
                [CmdletBinding()] param(
                    [string]$Name, [string]$Version, [string]$Repository,
                    [switch]$TrustRepository, [switch]$NoClobber,
                    [switch]$AcceptLicense, [switch]$Prerelease,
                    [PSCredential]$Credential, [string]$Scope
                )
            }
            function Save-PSResource {
                [CmdletBinding()] param(
                    [string]$Name, [string]$Version, [string]$Repository,
                    [switch]$TrustRepository, [switch]$NoClobber,
                    [switch]$AcceptLicense, [switch]$Prerelease,
                    [PSCredential]$Credential, [string]$Path
                )
            }

            Mock Get-PSResourceRepository { [PSCustomObject]@{ Name = 'PSGallery'; Trusted = $true } }
            Mock Get-Module { } -ParameterFilter { $ListAvailable }
            Mock Find-PSResource { [PSCustomObject]@{ Name = 'TestModule'; Version = [version]'2.0.0' } }
            Mock Install-PSResource { }
            Mock Save-PSResource { }
            Mock Import-PSDependModule { }
            Mock Add-ToPsModulePathIfRequired { }
        }
    }

    Context 'Contract: default Version handling' {
        It 'Omits -Version when Version is not supplied (installs latest)' {
            $dep = New-PSDependFixture -DependencyName 'TestModule' -DependencyType 'PSResourceGet'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep
            }
            Should -Invoke -CommandName Install-PSResource -ModuleName PSDepend -Times 1 -Exactly `
                -ParameterFilter { -not $PSBoundParameters.ContainsKey('Version') }
        }

        It 'Passes -Version when an explicit version is supplied' {
            $dep = New-PSDependFixture -DependencyName 'TestModule' -DependencyType 'PSResourceGet' -Version '1.2.3'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep
            }
            Should -Invoke -CommandName Install-PSResource -ModuleName PSDepend -Times 1 -Exactly `
                -ParameterFilter { $Version -eq '1.2.3' }
        }
    }

    Context 'Contract: Name falls back to DependencyName' {
        It 'Uses DependencyName as the module name when Name is not set' {
            $dep = New-PSDependFixture -DependencyName 'FallbackModule' -DependencyType 'PSResourceGet'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep
            }
            Should -Invoke -CommandName Install-PSResource -ModuleName PSDepend -Times 1 -Exactly `
                -ParameterFilter { $Name -eq 'FallbackModule' }
        }

        It 'Prefers Name over DependencyName when both are set' {
            $dep = New-PSDependFixture -DependencyName 'IgnoredKey' -Name 'RealModule' -DependencyType 'PSResourceGet'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep
            }
            Should -Invoke -CommandName Install-PSResource -ModuleName PSDepend -Times 1 -Exactly `
                -ParameterFilter { $Name -eq 'RealModule' }
        }
    }

    Context 'PSDependAction = Test only' {
        It 'Returns $false when module is not installed' {
            $dep = New-PSDependFixture -DependencyName 'TestModule' -DependencyType 'PSResourceGet'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Test
            }
            $result | Should -Be $false
            Should -Invoke -CommandName Install-PSResource -ModuleName PSDepend -Times 0
        }

        It 'Returns $true when installed version matches requested version' {
            InModuleScope PSDepend {
                Mock Get-Module { [PSCustomObject]@{ Name = 'TestModule'; Version = [version]'1.2.3' } } `
                    -ParameterFilter { $ListAvailable }
            }
            $dep = New-PSDependFixture -DependencyName 'TestModule' -DependencyType 'PSResourceGet' -Version '1.2.3'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Test
            }
            $result | Should -Be $true
            Should -Invoke -CommandName Install-PSResource -ModuleName PSDepend -Times 0
        }
    }

    Context 'PSDependAction = Test,Install short-circuits when satisfied' {
        BeforeAll {
            InModuleScope PSDepend {
                Mock Get-Module { [PSCustomObject]@{ Name = 'TestModule'; Version = [version]'2.0.0' } } `
                    -ParameterFilter { $ListAvailable }
            }
        }

        It 'Skips Install-PSResource but still calls Import-PSDependModule' {
            $dep = New-PSDependFixture -DependencyName 'TestModule' -DependencyType 'PSResourceGet' -Version 'latest'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Test, Install
            }
            Should -Invoke -CommandName Install-PSResource    -ModuleName PSDepend -Times 0
            Should -Invoke -CommandName Import-PSDependModule -ModuleName PSDepend -Times 1
        }
    }

    Context 'NuGet range version syntax' {
        It 'Passes the range string to Install-PSResource and resolves a concrete version for Import' {
            InModuleScope PSDepend {
                Mock Get-Module { } -ParameterFilter { $ListAvailable }
                Mock Get-Module { [PSCustomObject]@{ Name = 'TestModule'; Version = [version]'1.5.0' } } `
                    -ParameterFilter { -not $ListAvailable }
            }
            $dep = New-PSDependFixture -DependencyName 'TestModule' -DependencyType 'PSResourceGet' -Version '[1.0.0, )'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Install, Import
            }
            Should -Invoke -CommandName Install-PSResource -ModuleName PSDepend -Times 1 -Exactly `
                -ParameterFilter { $Version -eq '[1.0.0, )' }
            Should -Invoke -CommandName Import-PSDependModule -ModuleName PSDepend -Times 1 -Exactly `
                -ParameterFilter { $Version -ne '[1.0.0, )' }
        }
    }

    Context 'Latest version comparison' {
        It 'Installs when installed version is behind the repository version' {
            InModuleScope PSDepend {
                Mock Get-Module { [PSCustomObject]@{ Name = 'TestModule'; Version = [version]'2.8.0' } } `
                    -ParameterFilter { $ListAvailable }
                Mock Find-PSResource { [PSCustomObject]@{ Name = 'TestModule'; Version = [version]'2.10.0' } }
            }
            $dep = New-PSDependFixture -DependencyName 'TestModule' -DependencyType 'PSResourceGet' -Version 'latest'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep
            }
            Should -Invoke -CommandName Install-PSResource -ModuleName PSDepend -Times 1
        }
    }

    Context 'Multiple installed versions — requested version present but not the maximum' {
        It 'Returns $true and skips Install when the requested version is installed (even if a higher version also exists)' {
            InModuleScope PSDepend {
                Mock Get-Module {
                    @(
                        [PSCustomObject]@{ Name = 'TestModule'; Version = [version]'1.2.3' }
                        [PSCustomObject]@{ Name = 'TestModule'; Version = [version]'2.0.0' }
                    )
                } -ParameterFilter { $ListAvailable }
            }
            $dep = New-PSDependFixture -DependencyName 'TestModule' -DependencyType 'PSResourceGet' -Version '1.2.3'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Test
            }
            $result | Should -Be $true
            Should -Invoke -CommandName Install-PSResource -ModuleName PSDepend -Times 0
        }
    }

    Context 'Target as path uses Save-PSResource instead of Install-PSResource' {
        It 'Calls Save-PSResource with -Path and skips Install-PSResource' {
            $savePath = (New-Item 'TestDrive:/psresourceget-save' -ItemType Directory -Force).FullName
            $dep = New-PSDependFixture -DependencyName 'TestModule' -DependencyType 'PSResourceGet' -Target $savePath
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep
            }
            Should -Invoke -CommandName Save-PSResource -ModuleName PSDepend -Times 1 -Exactly `
                -ParameterFilter { $Path -eq $savePath }
            Should -Invoke -CommandName Install-PSResource -ModuleName PSDepend -Times 0
        }
    }

    Context 'Credential pass-through' {
        It 'Forwards Credential to Install-PSResource' {
            $dep = New-PSDependFixture -DependencyName 'PrivateModule' -DependencyType 'PSResourceGet' `
                -Credential $script:TestCred
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep
            }
            Should -Invoke -CommandName Install-PSResource -ModuleName PSDepend -Times 1 -Exactly `
                -ParameterFilter { $Credential -and $Credential.UserName -eq 'testUser' }
        }
    }

    Context 'Repository validation' {
        BeforeAll {
            InModuleScope PSDepend {
                Mock Get-PSResourceRepository { } -ParameterFilter { $Name -eq 'BogusRepo' }
            }
        }

        It 'Writes an error and skips install when the repository is not registered' {
            $dep = New-PSDependFixture -DependencyName 'TestModule' -DependencyType 'PSResourceGet' `
                -Parameters @{ Repository = 'BogusRepo' }
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -Repository 'BogusRepo' -ErrorAction SilentlyContinue
            }
            Should -Invoke -CommandName Install-PSResource -ModuleName PSDepend -Times 0
        }
    }

    Context 'PSResourceGet availability guard' {
        It 'Returns early without installing when Install-PSResource is not available' {
            InModuleScope PSDepend {
                # Intercept the guard check: Get-Command is safe to mock inside an It block
                # (Pester's own mock setup finished in BeforeAll; this only affects the script's call)
                Mock Get-Command { } -ParameterFilter { $Name -eq 'Install-PSResource' }
            }
            $dep = New-PSDependFixture -DependencyName 'TestModule' -DependencyType 'PSResourceGet'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -ErrorAction SilentlyContinue
            }
            Should -Invoke -CommandName Install-PSResource -ModuleName PSDepend -Times 0
        }
    }

    Context 'TrustRepository' {
        It 'Always passes TrustRepository to Install-PSResource for unattended use' {
            $dep = New-PSDependFixture -DependencyName 'TestModule' -DependencyType 'PSResourceGet'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep
            }
            Should -Invoke -CommandName Install-PSResource -ModuleName PSDepend -Times 1 -Exactly `
                -ParameterFilter { $TrustRepository -eq $true }
        }
    }
}
