#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/Npm.ps1'
}

Describe 'Npm script' {

    BeforeAll {
        InModuleScope PSDepend {
            Mock Get-NodeModule     { @{} }
            Mock Install-NodeModule { }
        }
    }

    It 'Installs globally when Target is "global"' {
        $dep = New-PSDependFixture -DependencyName 'left-pad' -DependencyType 'Npm' -Target 'global'
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        Should -Invoke -CommandName Install-NodeModule -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
            $Global -eq $true -and $PackageName -eq 'left-pad'
        }
    }

    It 'Installs locally (no -Global) when Target is a path' {
        $targetDir = (New-Item 'TestDrive:/npm-target' -ItemType Directory -Force).FullName
        $dep = New-PSDependFixture -DependencyName 'left-pad' -DependencyType 'Npm' -Target $targetDir
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        Should -Invoke -CommandName Install-NodeModule -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
            -not $Global -and $PackageName -eq 'left-pad'
        }
    }

    It 'PSDependAction Test returns $false when module is not installed' {
        $dep = New-PSDependFixture -DependencyName 'left-pad' -DependencyType 'Npm' -Target 'global'
        $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -PSDependAction Test
        }
        $result | Should -Be $false
        Should -Invoke -CommandName Install-NodeModule -ModuleName PSDepend -Times 0
    }

    It 'PSDependAction Test returns $true when an installed version exists' {
        InModuleScope PSDepend {
            Mock Get-NodeModule { @{ 'left-pad' = @{ Version = '1.3.0' } } }
        }
        $dep = New-PSDependFixture -DependencyName 'left-pad' -DependencyType 'Npm' -Target 'global'
        $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -PSDependAction Test
        }
        $result | Should -Be $true
    }
}
