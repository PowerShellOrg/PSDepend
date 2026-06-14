# cspell:ignore jquery
#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/Package.ps1'

    # PackageManagement cmdlets have complex dynamic parameter sets that Pester
    # cannot mock directly. Inject simple stub functions into the module's
    # script scope so Pester can wrap them with Mock.
    & (Get-Module PSDepend) {
        function script:Get-PackageSource { [CmdletBinding()] param() }
        function script:Get-PackageProvider { [CmdletBinding()] param() }
        function script:Get-Package { [CmdletBinding()] param([string]$Name, [string]$ProviderName, [string]$RequiredVersion, [string]$Destination, [string]$ErrorAction) }
        function script:Find-Package { [CmdletBinding()] param([string]$Name, [string]$Source) }
        function script:Install-Package { [CmdletBinding()] param([string]$Name, [string]$Source, [string]$RequiredVersion, [string]$Destination, [string]$Scope, [switch]$Force) }
    }
}

Describe 'Package script' {

    BeforeAll {
        InModuleScope PSDepend {
            Mock Get-PackageSource { [PSCustomObject]@{ Name = 'nuget.org'; ProviderName = 'Nuget' } }
            Mock Get-PackageProvider { @( [PSCustomObject]@{ Name = 'Nuget' }, [PSCustomObject]@{ Name = 'PowerShellGet' } ) }
            Mock Get-Package { }
            Mock Find-Package { [PSCustomObject]@{ Name = 'jquery'; Version = '1.0.0' } }
            Mock Install-Package { }
        }
    }

    It 'Calls Install-Package when no existing package is found' {
        $targetDir = (New-Item 'TestDrive:/pkg' -ItemType Directory -Force).FullName
        $dep = New-PSDependFixture -DependencyName 'jquery' -DependencyType 'Package' -Target $targetDir -Source 'nuget.org'
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        Should -Invoke -CommandName Install-Package -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'jquery' -and $Source -eq 'nuget.org'
        }
    }

    It 'Errors and returns when Source is not a known PackageSource' {
        $targetDir = (New-Item 'TestDrive:/pkg2' -ItemType Directory -Force).FullName
        $dep = New-PSDependFixture -DependencyName 'jquery' -DependencyType 'Package' -Target $targetDir -Source 'BogusFeed'
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -ErrorAction SilentlyContinue
        }
        Should -Invoke -CommandName Install-Package -ModuleName PSDepend -Times 0
    }

    It 'Throws when Nuget provider is selected but no Target is supplied' {
        $dep = New-PSDependFixture -DependencyName 'jquery' -DependencyType 'Package' -Source 'nuget.org'
        {
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep
            }
        } | Should -Throw -ExpectedMessage '*Nuget*Target*'
    }

    It 'Installs when installed version 2.8.0 is behind source version 2.10.0 and latest is requested' {
        $targetDir = (New-Item 'TestDrive:/pkg3' -ItemType Directory -Force).FullName
        InModuleScope PSDepend {
            Mock Get-Package { [PSCustomObject]@{ Name = 'jquery'; Version = [version]'2.8.0' } }
            Mock Find-Package { [PSCustomObject]@{ Name = 'jquery'; Version = [version]'2.10.0' } }
        }

        $dep = New-PSDependFixture -DependencyName 'jquery' -DependencyType 'Package' -Target $targetDir -Source 'nuget.org' -Version 'latest'
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }

        Should -Invoke -CommandName Install-Package -ModuleName PSDepend -Times 1
    }
}
