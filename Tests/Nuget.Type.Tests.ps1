# cspell:ignore Newtonsoft noplatform
#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/Nuget.ps1'
}

Describe 'Nuget script' {

    BeforeAll {
        InModuleScope PSDepend {
            Mock Invoke-ExternalCommand { }
            Mock Find-NugetPackage { [PSCustomObject]@{ Version = '1.0.0' } }
            # Pretend nuget.exe is available so we don't trigger the missing-tool Write-Error
            Mock Get-Command { [PSCustomObject]@{ Name = 'nuget' } } -ParameterFilter { $Name -eq 'Nuget' }
        }
    }

    It 'Errors when Target is not provided' {
        $dep = New-PSDependFixture -DependencyName 'Newtonsoft.Json' -DependencyType 'Nuget'
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -ErrorAction SilentlyContinue
        }
        Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 0
    }

    It 'Invokes nuget install when no existing package is found at the target' {
        $targetDir = (New-Item 'TestDrive:/nuget-target' -ItemType Directory -Force).FullName
        $dep = New-PSDependFixture -DependencyName 'Newtonsoft.Json' -DependencyType 'Nuget' -Target $targetDir
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 1 -ParameterFilter {
            $Arguments -contains 'install'
        }
    }

    It 'Adds -version arg when an explicit version is requested' {
        $targetDir = (New-Item 'TestDrive:/nuget-version' -ItemType Directory -Force).FullName
        $dep = New-PSDependFixture -DependencyName 'Newtonsoft.Json' -DependencyType 'Nuget' -Target $targetDir -Version '12.0.2'
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 1 -ParameterFilter {
            $Arguments -contains '-version' -and $Arguments -contains '12.0.2'
        }
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
            $targetDir = (New-Item 'TestDrive:/nuget-bootstrap' -ItemType Directory -Force).FullName
            $dep = New-PSDependFixture -DependencyName 'Newtonsoft.Json' -DependencyType 'Nuget' -Target $targetDir
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -ErrorAction SilentlyContinue
            }
            Should -Invoke -CommandName BootStrap-Nuget -ModuleName PSDepend -Times 1
        }

        It 'Does not invoke nuget install when nuget.exe is still missing after bootstrap' {
            $targetDir = (New-Item 'TestDrive:/nuget-bootstrap-fail' -ItemType Directory -Force).FullName
            $dep = New-PSDependFixture -DependencyName 'Newtonsoft.Json' -DependencyType 'Nuget' -Target $targetDir
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -ErrorAction SilentlyContinue
            }
            Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 0
        }

        It 'Does not call BootStrap-Nuget on an unsupported platform' {
            InModuleScope PSDepend {
                Mock Test-PlatformSupport { $false }
            }
            $targetDir = (New-Item 'TestDrive:/nuget-bootstrap-noplatform' -ItemType Directory -Force).FullName
            $dep = New-PSDependFixture -DependencyName 'Newtonsoft.Json' -DependencyType 'Nuget' -Target $targetDir
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -ErrorAction SilentlyContinue
            }
            Should -Invoke -CommandName BootStrap-Nuget -ModuleName PSDepend -Times 0
        }
    }
}
