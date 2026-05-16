#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force
    $script:SkipUnsupported = -not (Test-PSDependTypeSupportedHere -DependencyType 'WindowsRSAT')
}

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/WindowsRSAT.ps1'

    # Inject stub functions for the install-side cmdlets into the PSDepend
    # module scope so Pester's Mock attaches to a regular PowerShell function
    # rather than to the underlying CDXML/binary cmdlets. PowerShell resolves
    # functions before cmdlets in the same scope, so on hosts where the real
    # cmdlets exist (Windows Server PS 5.1 with ServerManager, Windows client
    # with DISM) the stub still wins. Mocking the real CDXML cmdlets has been
    # observed to silently not intercept on Windows PowerShell 5.1 -- the
    # stub-function approach makes mocking work consistently across PS 5.1,
    # PS 7, and all platforms.
    InModuleScope PSDepend {
        function script:Install-WindowsFeature { [CmdletBinding()] param([string]$Name) }
        function script:Add-WindowsCapability  { [CmdletBinding()] param([switch]$Online, [string]$Name) }
    }
}

Describe 'WindowsRSAT script' -Tag 'WindowsOnly' -Skip:$SkipUnsupported {

    BeforeAll {
        InModuleScope PSDepend {
            Mock Get-Module             { } -ParameterFilter { $ListAvailable }
            Mock Install-WindowsFeature { }
            Mock Add-WindowsCapability  { }
            Mock Get-CimInstance        { [PSCustomObject]@{ ProductType = 3 } } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
            Mock Import-PSDependModule  { }
            Mock Test-Administrator     { $true }
        }
    }

    Context 'PSDependAction = Test only' {
        It 'Returns $false when the module is not installed' {
            $dep = New-PSDependFixture -DependencyName 'ActiveDirectory' -DependencyType 'WindowsRSAT'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Test
            }
            $result | Should -Be $false
            Should -Invoke -CommandName Install-WindowsFeature -ModuleName PSDepend -Times 0
            Should -Invoke -CommandName Add-WindowsCapability  -ModuleName PSDepend -Times 0
        }

        It 'Returns $true when the module is already available' {
            InModuleScope PSDepend {
                Mock Get-Module { [PSCustomObject]@{ Name = 'ActiveDirectory' } } -ParameterFilter { $ListAvailable }
            }
            $dep = New-PSDependFixture -DependencyName 'ActiveDirectory' -DependencyType 'WindowsRSAT'
            $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Test
            }
            $result | Should -Be $true
            Should -Invoke -CommandName Install-WindowsFeature -ModuleName PSDepend -Times 0
        }
    }

    Context 'PSDependAction = Install on Server' {

        It 'Dispatches to Install-WindowsFeature with the mapped name (<ModuleName> -> <Feature>)' -TestCases @(
            @{ ModuleName = 'ActiveDirectory'; Feature = 'RSAT-AD-Powershell' }
            @{ ModuleName = 'BitLocker';       Feature = 'RSAT-Feature-Tools-BitLocker-RemoteAdminTool' }
            @{ ModuleName = 'Hyper-V';         Feature = 'RSAT-Hyper-V-Tools' }
            @{ ModuleName = 'GroupPolicy';     Feature = 'GPMC' }
        ) {
            param($ModuleName, $Feature)

            $dep = New-PSDependFixture -DependencyName $ModuleName -DependencyType 'WindowsRSAT'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Install
            }
            Should -Invoke -CommandName Install-WindowsFeature -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
                $Name -eq $Feature
            }
            Should -Invoke -CommandName Add-WindowsCapability  -ModuleName PSDepend -Times 0
        }

        It 'Throws when the module name is not in the mapping table' {
            $dep = New-PSDependFixture -DependencyName 'NotARealModule' -DependencyType 'WindowsRSAT'
            {
                InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                    & $ScriptPath -Dependency $Dep -PSDependAction Install
                }
            } | Should -Throw '*Unknown Module*'
        }
    }

    Context 'PSDependAction = Install on Workstation' {

        BeforeAll {
            InModuleScope PSDepend {
                Mock Get-CimInstance { [PSCustomObject]@{ ProductType = 1 } } -ParameterFilter { $ClassName -eq 'Win32_OperatingSystem' }
            }
        }

        It 'Dispatches to Add-WindowsCapability with the mapped name (<ModuleName> -> <Capability>)' -TestCases @(
            @{ ModuleName = 'ActiveDirectory'; Capability = 'Rsat.ActiveDirectory.DS-LDS.Tools' }
            @{ ModuleName = 'BitLocker';       Capability = 'Rsat.BitLocker.Recovery.Tools' }
            @{ ModuleName = 'GroupPolicy';     Capability = 'Rsat.GroupPolicy.Management.Tools' }
        ) {
            param($ModuleName, $Capability)

            $dep = New-PSDependFixture -DependencyName $ModuleName -DependencyType 'WindowsRSAT'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Install
            }
            Should -Invoke -CommandName Add-WindowsCapability  -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
                $Name -eq $Capability
            }
            Should -Invoke -CommandName Install-WindowsFeature -ModuleName PSDepend -Times 0
        }
    }

    Context 'PSDependAction = Install gated by admin check' {
        It 'Throws when Test-Administrator returns $false' {
            InModuleScope PSDepend {
                Mock Test-Administrator { $false }
            }
            $dep = New-PSDependFixture -DependencyName 'ActiveDirectory' -DependencyType 'WindowsRSAT'
            {
                InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                    & $ScriptPath -Dependency $Dep -PSDependAction Install
                }
            } | Should -Throw '*admin*'
            Should -Invoke -CommandName Install-WindowsFeature -ModuleName PSDepend -Times 0
            Should -Invoke -CommandName Add-WindowsCapability  -ModuleName PSDepend -Times 0
        }
    }

    Context 'PSDependAction = Test, Install short-circuits when installed' {
        It 'Skips Install when the module is already available' {
            InModuleScope PSDepend {
                Mock Get-Module { [PSCustomObject]@{ Name = 'ActiveDirectory' } } -ParameterFilter { $ListAvailable }
            }
            $dep = New-PSDependFixture -DependencyName 'ActiveDirectory' -DependencyType 'WindowsRSAT'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep -PSDependAction Test, Install
            }
            Should -Invoke -CommandName Install-WindowsFeature -ModuleName PSDepend -Times 0
            Should -Invoke -CommandName Add-WindowsCapability  -ModuleName PSDepend -Times 0
        }
    }
}
