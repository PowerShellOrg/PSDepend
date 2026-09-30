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
            Mock Get-NodeModule { @{} }
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

    Context 'PSDependAction = Resolve' {
        It 'Picks the highest version when npm returns several' {
            InModuleScope PSDepend {
                Mock Find-NodeModule { [string[]]@('0.1.0', '0.3.2', '0.2.9') }
            }
            $dep = New-PSDependFixture -DependencyName 'left-pad' -DependencyType 'Npm' -Version '[0.1.0,0.4.0)'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Resolve
            }
            $result.Name | Should -Be 'left-pad'
            $result.Version | Should -Be '0.3.2'
            $result.Dependencies.Count | Should -Be 0
            Should -Invoke -CommandName Find-NodeModule -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
                $PackageName -eq 'left-pad' -and $Version -eq '[0.1.0,0.4.0)'
            }
        }

        It 'Returns the single version npm reports for latest' {
            InModuleScope PSDepend {
                Mock Find-NodeModule { [string[]]@('1.3.0') }
            }
            $dep = New-PSDependFixture -DependencyName 'left-pad' -DependencyType 'Npm'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Resolve
            }
            @($result).Count | Should -Be 1
            $result.Version | Should -Be '1.3.0'
        }

        It 'Writes an error and emits nothing when npm returns no versions' {
            InModuleScope PSDepend {
                Mock Find-NodeModule { }
            }
            $dep = New-PSDependFixture -DependencyName 'left-pad' -DependencyType 'Npm' -Version '9.9.9'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Resolve -ErrorAction SilentlyContinue -ErrorVariable err
                $err | Should -Not -BeNullOrEmpty
            }
            $result | Should -BeNullOrEmpty
            Should -Invoke -CommandName Install-NodeModule -ModuleName PSDepend -Times 0
        }
    }
}
