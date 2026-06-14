# cspell:ignore taskflag taskparam
#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/Task.ps1'
}

Describe 'Task script' {

    It 'Dot-sources a task script that exists on disk' {
        $taskFile = Join-Path 'TestDrive:' 'task1.ps1'
        $flagFile = Join-Path 'TestDrive:' 'taskflag.txt'
        $resolvedFlag = (Resolve-Path 'TestDrive:').ProviderPath
        $absoluteFlag = Join-Path $resolvedFlag 'taskflag.txt'
        Set-Content -Path $taskFile -Value "Set-Content -Path '$absoluteFlag' -Value 'task-ran'"

        $dep = New-PSDependFixture -DependencyName 'TaskOne' -DependencyType 'Task' -Source (Resolve-Path $taskFile).ProviderPath
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        (Get-Content $absoluteFlag) | Should -Be 'task-ran'
    }

    It 'Passes Parameters to the task script via splat' {
        $taskFile = Join-Path 'TestDrive:' 'task-params.ps1'
        $flagBase = (Resolve-Path 'TestDrive:').ProviderPath
        $outFile = Join-Path $flagBase 'taskparam.txt'
        Set-Content -Path $taskFile -Value "param(`$Greeting) Set-Content -Path '$outFile' -Value `$Greeting"

        $dep = New-PSDependFixture -DependencyName 'TaskParam' -DependencyType 'Task' `
            -Source (Resolve-Path $taskFile).ProviderPath `
            -Parameters @{ Greeting = 'hi-from-test' }
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        (Get-Content $outFile) | Should -Be 'hi-from-test'
    }

    It 'Warns and does not throw when the task file is missing' {
        $missingPath = Join-Path $TestDrive 'nope.ps1'
        $dep = New-PSDependFixture -DependencyName 'TaskMissing' -DependencyType 'Task' -Source $missingPath
        $warnings = $null
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath; WarnRef = [ref]$warnings } {
            & $ScriptPath -Dependency $Dep -WarningVariable warn -WarningAction SilentlyContinue
            $WarnRef.Value = $warn
        }
        $warnings | Should -Not -BeNullOrEmpty
        ($warnings | Out-String) | Should -Match 'Could not find task file'
    }
}
