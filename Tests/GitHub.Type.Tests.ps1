#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        Set-BuildEnvironment -Path "$PSScriptRoot/.." -Force
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/GitHub.ps1'
}

Describe 'GitHub script' {

    BeforeAll {
        InModuleScope PSDepend {
            Mock Get-Module       { } -ParameterFilter { $ListAvailable }
            Mock Invoke-RestMethod { @() }   # No tags returned → treated as branch
            Mock Import-PSDependModule { }
        }
    }

    Context 'PSDependAction = Test only' {
        It 'Returns $false when module is not installed locally' {
            $targetDir = (New-Item 'TestDrive:/gh-test' -ItemType Directory -Force).FullName
            $dep = New-PSDependFixture -DependencyName 'someuser/somerepo' -DependencyType 'GitHub' -Target $targetDir -Version 'master'

            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Test -WarningAction SilentlyContinue
            }
            $result | Should -Be $false
        }
    }

    Context 'PSDependAction = Test when already installed and matches' {
        It 'Returns $true when local version matches requested numeric version' {
            InModuleScope PSDepend {
                Mock Get-Module {
                    [pscustomobject]@{ Name = 'somerepo'; Version = [version]'1.2.3' }
                } -ParameterFilter { $ListAvailable }
            }
            $targetDir = (New-Item 'TestDrive:/gh-match' -ItemType Directory -Force).FullName
            $dep = New-PSDependFixture -DependencyName 'someuser/somerepo' -DependencyType 'GitHub' -Target $targetDir -Version '1.2.3'

            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Test -WarningAction SilentlyContinue
            }
            $result | Should -Be $true
        }
    }
}
