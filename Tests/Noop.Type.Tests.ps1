#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        Set-BuildEnvironment -Path "$PSScriptRoot/.." -Force
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/Noop.ps1'
}

Describe 'Noop script' {
    It 'Returns an object containing the supplied Dependency' {
        $dep = New-PSDependFixture -DependencyName 'NoopOne'
        $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        $result.Dependency.DependencyName | Should -Be 'NoopOne'
    }

    It 'Passes StringParameter through to PSBoundParameters' {
        $dep = New-PSDependFixture -DependencyName 'NoopTwo'
        $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -StringParameter 'hello', 'world'
        }
        $result.PSBoundParameters['StringParameter'] | Should -Be @('hello', 'world')
    }
}
