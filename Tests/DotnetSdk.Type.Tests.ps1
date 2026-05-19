#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/DotnetSdk.ps1'
    $script:OrigPath = $env:PATH
}

AfterAll {
    if ($script:OrigPath) { $env:PATH = $script:OrigPath }
}

Describe 'DotnetSdk script' {

    BeforeAll {
        InModuleScope PSDepend {
            Mock Install-Dotnet { }
            Mock Test-Dotnet    { $false }
        }
    }

    It 'PSDependAction Test delegates to Test-Dotnet' {
        InModuleScope PSDepend { Mock Test-Dotnet { $true } }
        $dep = New-PSDependFixture -DependencyName 'release' -DependencyType 'DotnetSdk' -Version '2.1.0'
        $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -PSDependAction Test
        }
        $result | Should -Be $true
        Should -Invoke -CommandName Test-Dotnet -ModuleName PSDepend -Times 1
    }

    It 'Calls Install-Dotnet when Test-Dotnet reports SDK is missing' {
        $installDir = (New-Item 'TestDrive:/dotnet' -ItemType Directory -Force).FullName
        $dep = New-PSDependFixture -DependencyName 'release' -DependencyType 'DotnetSdk' -Version '2.1.0' -Target $installDir
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath; D = $installDir } {
            & $ScriptPath -Dependency $Dep
        }
        Should -Invoke -CommandName Install-Dotnet -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
            $Channel -eq 'release' -and $Version -eq '2.1.0' -and $InstallDir -eq $installDir
        }
    }

    It 'Skips Install-Dotnet when Test-Dotnet reports SDK is present' {
        InModuleScope PSDepend { Mock Test-Dotnet { $true } }
        $dep = New-PSDependFixture -DependencyName 'LTS' -DependencyType 'DotnetSdk' -Version '2.1.0'
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        Should -Invoke -CommandName Install-Dotnet -ModuleName PSDepend -Times 0
    }
}
