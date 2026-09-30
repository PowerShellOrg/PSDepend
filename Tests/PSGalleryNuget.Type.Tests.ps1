# cspell:ignore noplatform psgnuget
#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/PSGalleryNuget.ps1'
}

Describe 'PSGalleryNuget script' {

    BeforeAll {
        InModuleScope PSDepend {
            Mock Invoke-ExternalCommand { }
            Mock Find-NugetPackage { [PSCustomObject]@{ Version = '1.0.0' } }
            Mock Add-ToPsModulePathIfRequired { }
            Mock Import-PSDependModule { }
            Mock Get-Command { [PSCustomObject]@{ Name = 'nuget' } } -ParameterFilter { $Name -eq 'Nuget' }
        }
    }

    It 'Errors when Target is not provided' {
        $dep = New-PSDependFixture -DependencyName 'PSDeploy' -DependencyType 'PSGalleryNuget'
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -ErrorAction SilentlyContinue
        }
        Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 0
    }

    It 'Invokes nuget install when no module is present at the target' {
        $targetDir = (New-Item 'TestDrive:/psgnuget-target' -ItemType Directory -Force).FullName
        $dep = New-PSDependFixture -DependencyName 'PSDeploy' -DependencyType 'PSGalleryNuget' -Target $targetDir
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 1 -ParameterFilter {
            $Arguments -contains 'install'
        }
    }

    It 'Imports the module via Import-PSDependModule after install' {
        $targetDir = (New-Item 'TestDrive:/psgnuget-target2' -ItemType Directory -Force).FullName
        $dep = New-PSDependFixture -DependencyName 'PSDeploy' -DependencyType 'PSGalleryNuget' -Target $targetDir
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        Should -Invoke -CommandName Import-PSDependModule -ModuleName PSDepend -Times 1
    }

    Context 'NuGet bootstrap' {
        BeforeAll {
            InModuleScope PSDepend {
                Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Nuget' }
                Mock BootStrap-Nuget { }
                Mock Test-PlatformSupport { $true }
            }
        }

        It 'Calls BootStrap-Nuget when nuget.exe is missing on a supported platform' {
            $targetDir = (New-Item 'TestDrive:/psgnuget-bootstrap' -ItemType Directory -Force).FullName
            $dep = New-PSDependFixture -DependencyName 'PSDeploy' -DependencyType 'PSGalleryNuget' -Target $targetDir
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -ErrorAction SilentlyContinue
            }
            Should -Invoke -CommandName BootStrap-Nuget -ModuleName PSDepend -Times 1
        }

        It 'Does not invoke nuget install when nuget.exe is still missing after bootstrap' {
            $targetDir = (New-Item 'TestDrive:/psgnuget-bootstrap-fail' -ItemType Directory -Force).FullName
            $dep = New-PSDependFixture -DependencyName 'PSDeploy' -DependencyType 'PSGalleryNuget' -Target $targetDir
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -ErrorAction SilentlyContinue
            }
            Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 0
        }

        It 'Does not call BootStrap-Nuget on an unsupported platform' {
            InModuleScope PSDepend {
                Mock Test-PlatformSupport { $false }
            }
            $targetDir = (New-Item 'TestDrive:/psgnuget-bootstrap-noplatform' -ItemType Directory -Force).FullName
            $dep = New-PSDependFixture -DependencyName 'PSDeploy' -DependencyType 'PSGalleryNuget' -Target $targetDir
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -ErrorAction SilentlyContinue
            }
            Should -Invoke -CommandName BootStrap-Nuget -ModuleName PSDepend -Times 0
        }
    }

    Context 'Version range resolution' {
        It 'Resolves a range to the highest satisfying version and passes it to nuget install' {
            InModuleScope PSDepend {
                Mock Find-NugetPackage {
                    @(
                        [PSCustomObject]@{ Version = '1.9.0' }
                        [PSCustomObject]@{ Version = '2.5.0' }
                        [PSCustomObject]@{ Version = '3.0.0' }
                    )
                }
            }
            $targetDir = (New-Item 'TestDrive:/psgnuget-range' -ItemType Directory -Force).FullName
            $dep = New-PSDependFixture -DependencyName 'PSDeploy' -DependencyType 'PSGalleryNuget' -Target $targetDir -Version '[2.0.0,3.0.0)'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep
            }
            Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 1 -ParameterFilter {
                $i = [array]::IndexOf($Arguments, '-version')
                $i -ge 0 -and $Arguments[$i + 1] -eq '2.5.0'
            }
        }

        It 'Errors and skips nuget install when no version satisfies the range' {
            InModuleScope PSDepend {
                Mock Find-NugetPackage { @([PSCustomObject]@{ Version = '1.0.0' }) }
            }
            $targetDir = (New-Item 'TestDrive:/psgnuget-range-none' -ItemType Directory -Force).FullName
            $dep = New-PSDependFixture -DependencyName 'PSDeploy' -DependencyType 'PSGalleryNuget' -Target $targetDir -Version '[2.0.0,3.0.0)'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -ErrorAction SilentlyContinue
            }
            Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 0
        }

        It 'Errors and skips nuget install for a malformed range instead of passing it to nuget' {
            $targetDir = (New-Item 'TestDrive:/psgnuget-range-malformed' -ItemType Directory -Force).FullName
            $dep = New-PSDependFixture -DependencyName 'PSDeploy' -DependencyType 'PSGalleryNuget' -Target $targetDir -Version '[1.0.0,2.0.0'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -ErrorAction SilentlyContinue
            }
            Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 0
        }
    }

    Context 'PSDependAction = Resolve' {
        BeforeAll {
            InModuleScope PSDepend {
                Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Nuget' }
                Mock BootStrap-Nuget { }
                Mock Find-NugetPackage {
                    @(
                        [PSCustomObject]@{ Version = '1.9.0'; Properties = @{ IsPrerelease = 'false'; Dependencies = '' } }
                        [PSCustomObject]@{ Version = '2.5.0'; Properties = @{ IsPrerelease = 'false'; Dependencies = 'PSDeploy:0.2.5:|BuildHelpers:[2.0.0, ):' } }
                        [PSCustomObject]@{ Version = '2.9.0-beta1'; Properties = @{ IsPrerelease = 'true'; Dependencies = '' } }
                        [PSCustomObject]@{ Version = '3.0.0'; Properties = @{ IsPrerelease = 'false'; Dependencies = 'BuildHelpers::' } }
                        [PSCustomObject]@{ Version = '3.1.0-beta1'; Properties = @{ IsPrerelease = 'true'; Dependencies = '' } }
                    )
                }
            }
        }

        It 'Resolves a range to the highest in-range version without a Target or nuget.exe' {
            $dep = New-PSDependFixture -DependencyName 'PSDeploy' -DependencyType 'PSGalleryNuget' -Version '[2.0.0,3.0.0)'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Resolve
            }
            $result.Name | Should -Be 'PSDeploy'
            $result.Version | Should -Be '2.5.0'
            $result.Dependencies['PSDeploy'] | Should -Be '[0.2.5,)'
            $result.Dependencies['BuildHelpers'] | Should -Be '[2.0.0,)'
            $result.Dependencies.Count | Should -Be 2
            Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 0
            Should -Invoke -CommandName BootStrap-Nuget -ModuleName PSDepend -Times 0
            Should -Invoke -CommandName Import-PSDependModule -ModuleName PSDepend -Times 0
        }

        It 'Resolves latest to the highest stable version, skipping prerelease' {
            $dep = New-PSDependFixture -DependencyName 'PSDeploy' -DependencyType 'PSGalleryNuget'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Resolve
            }
            $result.Version | Should -Be '3.0.0'
            $result.Dependencies['BuildHelpers'] | Should -Be 'latest'
        }

        It 'Errors with no output when nothing satisfies the range' {
            $dep = New-PSDependFixture -DependencyName 'PSDeploy' -DependencyType 'PSGalleryNuget' -Version '[5.0.0,)'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Resolve -ErrorAction SilentlyContinue -ErrorVariable e
                $e.Count | Should -Be 1
                $e[0] | Should -Match 'No version of \[PSDeploy\]'
            }
            $result | Should -BeNullOrEmpty
            Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 0
        }

        It 'Rejects an HTTP source when credentials would be transmitted' {
            $credential = New-TestCredential -UserName 'feeduser' -Password 'feedpass'
            $dep = New-PSDependFixture -DependencyName 'PSDeploy' -DependencyType 'PSGalleryNuget' `
                -Source 'http://packages.example.test/api/v2/' -Credential $credential

            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Resolve -ErrorAction SilentlyContinue -ErrorVariable err
                $err[0].ToString() | Should -Match 'requires an HTTPS Source'
            }

            $result | Should -BeNullOrEmpty
            Should -Invoke -CommandName Find-NugetPackage -ModuleName PSDepend -Times 0 -Exactly
        }
    }
}
