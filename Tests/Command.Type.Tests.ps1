#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/Command.ps1'
}

Describe 'Command script' {

    It 'Executes the Source string as PowerShell in the current session' {
        $flagPath = Join-Path 'TestDrive:' 'flag.txt'
        $dep = New-PSDependFixture -DependencyName 'CmdOne' -DependencyType 'Command' -Source "Set-Content -Path '$flagPath' -Value 'ran'"
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        (Get-Content $flagPath) | Should -Be 'ran'
    }

    It 'Iterates multiple Source entries' {
        $countPath = Join-Path 'TestDrive:' 'count.txt'
        $dep = New-PSDependFixture -DependencyName 'CmdMulti' -DependencyType 'Command' -Source @(
            "Add-Content '$countPath' 'a'"
            "Add-Content '$countPath' 'b'"
        )
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        (Get-Content $countPath) | Should -Be @('a', 'b')
    }

    It 'Writes a non-terminating error and continues by default when the Source errors' {
        $dep = New-PSDependFixture -DependencyName 'CmdSwallow' -DependencyType 'Command' -Source "throw 'boom'"
        $err = $null
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath; ErrRef = [ref]$err } {
            & $ScriptPath -Dependency $Dep -ErrorAction SilentlyContinue -ErrorVariable scriptErr
            $ErrRef.Value = $scriptErr
        }
        $err | Should -Not -BeNullOrEmpty
        ($err | Out-String) | Should -Match 'boom'
    }

    It 'Throws a terminating error when -FailOnError is specified' {
        $dep = New-PSDependFixture -DependencyName 'CmdFail' -DependencyType 'Command' -Source "throw 'boom'"
        {
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -FailOnError
            }
        } | Should -Throw -ExpectedMessage '*boom*'
    }
}
