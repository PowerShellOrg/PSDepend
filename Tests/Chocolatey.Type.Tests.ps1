#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force
    $script:SkipUnsupported = -not (Test-PSDependTypeSupportedHere -DependencyType 'Chocolatey')
}

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/Chocolatey.ps1'
}

Describe 'Chocolatey script' -Tag 'WindowsOnly' -Skip:$SkipUnsupported {

    BeforeAll {
        InModuleScope PSDepend {
            # Pretend choco.exe is present so we skip the bootstrap branch
            Mock Get-Command { [PSCustomObject]@{ Name = 'choco.exe' } } -ParameterFilter { $Name -eq 'choco.exe' }
            # All choco invocations return empty CSV (no packages installed, none found upstream)
            Mock Invoke-ExternalCommand { }
            Mock Invoke-WebRequest { }
        }
    }

    It 'Defaults Source to https://community.chocolatey.org/api/v2/ when not supplied' {
        $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey'
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -Force
        }
        Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
            ($Arguments -join ' ') -match "--source='https://community\.chocolatey\.org/api/v2/'"
        }
    }

    It 'Passes --yes to choco upgrade to suppress interactive prompts' {
        $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version '2.0.2'
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -Force
        }
        Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
            $Arguments -contains 'upgrade' -and $Arguments -contains '--yes'
        }
    }

    It 'Invokes choco upgrade with -Force when -Force switch is set' {
        $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version '2.0.2'
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -Force
        }
        Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
            $Arguments -contains 'upgrade' -and $Arguments -contains '--force'
        }
    }

    It 'Forwards Credential to choco as --username / --password args' {
        $cred = New-TestCredential -UserName 'feeduser' -Password 'feedpass'
        $dep = New-PSDependFixture -DependencyName 'git' -DependencyType 'Chocolatey' -Version '2.0.2' -Credential $cred
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -Force
        }
        Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
            ($Arguments -join ' ') -match "--username='feeduser'" -and ($Arguments -join ' ') -match "--password='feedpass'"
        }
    }
}
