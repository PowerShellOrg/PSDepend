#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        Set-BuildEnvironment -Path "$PSScriptRoot/.." -Force
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/PSGalleryNuget.ps1'
}

Describe 'PSGalleryNuget script' {

    BeforeAll {
        InModuleScope PSDepend {
            Mock Invoke-ExternalCommand        { }
            Mock Find-NugetPackage             { [pscustomobject]@{ Version = '1.0.0' } }
            Mock Add-ToPsModulePathIfRequired  { }
            Mock Import-PSDependModule         { }
            Mock Get-Command { [pscustomobject]@{ Name = 'nuget' } } -ParameterFilter { $Name -eq 'Nuget' }
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
}
