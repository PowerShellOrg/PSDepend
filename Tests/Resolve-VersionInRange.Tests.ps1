#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force
}

Describe 'Resolve-VersionInRange' {

    It 'Returns the highest candidate inside a half-open range' {
        InModuleScope PSDepend {
            Resolve-VersionInRange -Candidate '1.9.0', '2.5.0', '3.0.0' -Required '[2.0.0,3.0.0)'
        } | Should -Be '2.5.0'
    }

    It 'Picks the maximum regardless of candidate order' {
        InModuleScope PSDepend {
            Resolve-VersionInRange -Candidate '2.5.0', '2.1.0', '2.9.0' -Required '[2.0.0,3.0.0)'
        } | Should -Be '2.9.0'
    }

    It 'Returns the exact version when it is available' {
        InModuleScope PSDepend {
            Resolve-VersionInRange -Candidate '1.0.0', '2.0.0', '3.0.0' -Required '2.0.0'
        } | Should -Be '2.0.0'
    }

    It 'Returns null when no candidate satisfies the range' {
        InModuleScope PSDepend {
            Resolve-VersionInRange -Candidate '1.0.0', '3.5.0' -Required '[2.0.0,3.0.0)'
        } | Should -BeNullOrEmpty
    }

    It 'Returns null for an empty candidate set' {
        InModuleScope PSDepend {
            Resolve-VersionInRange -Candidate @() -Required '[2.0.0,3.0.0)'
        } | Should -BeNullOrEmpty
    }

    It 'Excludes the exclusive upper bound' {
        InModuleScope PSDepend {
            Resolve-VersionInRange -Candidate '2.9.0', '3.0.0' -Required '[2.0.0,3.0.0)'
        } | Should -Be '2.9.0'
    }
}
