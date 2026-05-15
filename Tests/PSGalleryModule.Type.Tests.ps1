#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        Set-BuildEnvironment -Path "$PSScriptRoot/.." -Force
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/PSGalleryModule.ps1'
    $script:TestCred = New-TestCredential
    $script:OrigPSModulePath = $env:PSModulePath
}

AfterAll {
    if ($script:OrigPSModulePath) {
        $env:PSModulePath = $script:OrigPSModulePath
    }
}

Describe 'PSGalleryModule script' {

    BeforeAll {
        InModuleScope PSDepend {
            Mock Get-PackageProvider { [PSCustomObject]@{ Name = 'NuGet' } }
            Mock Get-PSRepository    { [PSCustomObject]@{ Name = 'PSGallery' } }
            Mock Get-Module          { } -ParameterFilter { $ListAvailable }
            Mock Find-Module         { [PSCustomObject]@{ Name = 'TestModule'; Version = [version]'2.0.0' } }
            Mock Install-Module      { }
            Mock Save-Module         { }
            Mock Import-PSDependModule     { }
            Mock Add-ToPsModulePathIfRequired { }
        }
    }

    Context 'Contract: default Version handling' {
        It 'Defaults to latest (no RequiredVersion in splat) when Version is not supplied' {
            $dep = New-PSDependFixture -DependencyName 'TestModule'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep
            }
            Should -Invoke -CommandName Install-Module -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
                -not $PSBoundParameters.ContainsKey('RequiredVersion')
            }
        }

        It 'Passes RequiredVersion when an explicit version is supplied' {
            $dep = New-PSDependFixture -DependencyName 'TestModule' -Version '1.2.3'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep
            }
            Should -Invoke -CommandName Install-Module -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
                $RequiredVersion -eq '1.2.3'
            }
        }
    }

    Context 'Contract: Name falls back to DependencyName' {
        It 'Uses DependencyName as the module name when Name is not set' {
            $dep = New-PSDependFixture -DependencyName 'FallbackModule'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep
            }
            Should -Invoke -CommandName Install-Module -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'FallbackModule'
            }
        }

        It 'Prefers Name over DependencyName when both are set' {
            $dep = New-PSDependFixture -DependencyName 'IgnoredKey' -Name 'RealModule'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep
            }
            Should -Invoke -CommandName Install-Module -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'RealModule'
            }
        }
    }

    Context 'PSDependAction = Test only' {
        It 'Returns $false when module is not installed' {
            $dep = New-PSDependFixture -DependencyName 'TestModule'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Test
            }
            $result | Should -Be $false
            Should -Invoke -CommandName Install-Module -ModuleName PSDepend -Times 0
        }

        It 'Returns $true when installed version matches requested version' {
            InModuleScope PSDepend {
                Mock Get-Module { [PSCustomObject]@{ Name = 'TestModule'; Version = [version]'1.2.3' } } -ParameterFilter { $ListAvailable }
            }
            $dep = New-PSDependFixture -DependencyName 'TestModule' -Version '1.2.3'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Test
            }
            $result | Should -Be $true
            Should -Invoke -CommandName Install-Module -ModuleName PSDepend -Times 0
        }
    }

    Context 'PSDependAction = Test,Install short-circuits when satisfied' {
        BeforeAll {
            InModuleScope PSDepend {
                Mock Get-Module { [PSCustomObject]@{ Name = 'TestModule'; Version = [version]'2.0.0' } } -ParameterFilter { $ListAvailable }
            }
        }

        It 'Skips Install-Module but still calls Import-PSDependModule' {
            $dep = New-PSDependFixture -DependencyName 'TestModule' -Version 'latest'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Test, Install
            }
            Should -Invoke -CommandName Install-Module       -ModuleName PSDepend -Times 0
            Should -Invoke -CommandName Import-PSDependModule -ModuleName PSDepend -Times 1
        }
    }

    Context 'Latest version comparison' {
        It 'Installs when installed version 2.8.0 is behind gallery version 2.10.0' {
            InModuleScope PSDepend {
                Mock Get-Module { [PSCustomObject]@{ Name = 'TestModule'; Version = [version]'2.8.0' } } -ParameterFilter { $ListAvailable }
                Mock Find-Module { [PSCustomObject]@{ Name = 'TestModule'; Version = [version]'2.10.0' } }
            }
            $dep = New-PSDependFixture -DependencyName 'TestModule' -Version 'latest'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep
            }

            Should -Invoke -CommandName Install-Module -ModuleName PSDepend -Times 1
        }
    }

    Context 'Target as path uses Save-Module instead of Install-Module' {
        It 'Calls Save-Module with the target path' {
            $savePath = (New-Item 'TestDrive:/save' -ItemType Directory -Force).FullName
            $dep = New-PSDependFixture -DependencyName 'TestModule' -Target $savePath
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath; SavePath = $savePath } {
                & $ScriptPath -Dependency $Dep
            }
            Should -Invoke -CommandName Save-Module    -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
                $Path -eq $savePath
            }
            Should -Invoke -CommandName Install-Module -ModuleName PSDepend -Times 0
        }
    }

    Context 'Credential pass-through' {
        It 'Forwards Credential to Install-Module' {
            $dep = New-PSDependFixture -DependencyName 'PrivateModule' -Credential $script:TestCred
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep
            }
            Should -Invoke -CommandName Install-Module -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
                $Credential -and $Credential.UserName -eq 'testUser'
            }
        }
    }

    Context 'Repository validation' {
        It 'Errors and skips install when repository is unknown' {
            InModuleScope PSDepend {
                Mock Get-PSRepository { } -ParameterFilter { $Name -eq 'BogusRepo' }
            }
            $dep = New-PSDependFixture -DependencyName 'TestModule' -Parameters @{ Repository = 'BogusRepo' }
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -Repository 'BogusRepo' -ErrorAction SilentlyContinue
            }
            Should -Invoke -CommandName Install-Module -ModuleName PSDepend -Times 0
        }
    }
}
