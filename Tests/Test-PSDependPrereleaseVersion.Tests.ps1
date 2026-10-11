#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force
}

Describe 'Test-PSDependPrereleaseVersion' {

    Context 'Realistic prerelease versions (should warn)' {

        It 'Detects a single alphanumeric prerelease label (<Version>)' -TestCases @(
            @{ Version = '2.5.0-alpha' }
            @{ Version = '0.7.0-beta1' }
            @{ Version = '1.2.3-rc1' }
        ) {
            InModuleScope PSDepend -Parameters @{ Version = $Version } {
                param($Version)
                Test-PSDependPrereleaseVersion -Version $Version
            } | Should -Be $true
        }

        It 'Detects a dotted SemVer 2.0 prerelease label even though PowerShellGet module tags forbid dots (<Version>)' -TestCases @(
            @{ Version = '1.0.0-beta.1' }
        ) {
            InModuleScope PSDepend -Parameters @{ Version = $Version } {
                param($Version)
                Test-PSDependPrereleaseVersion -Version $Version
            } | Should -Be $true
        }

        It 'Detects a prerelease label with SemVer build metadata (<Version>)' -TestCases @(
            @{ Version = '1.0.0-beta+build.5' }
            @{ Version = '1.0.0-beta1+001' }
        ) {
            InModuleScope PSDepend -Parameters @{ Version = $Version } {
                param($Version)
                Test-PSDependPrereleaseVersion -Version $Version
            } | Should -Be $true
        }

        It 'Detects a leading-zero numeric prerelease identifier even though SemVer forbids it (<Version>)' -TestCases @(
            @{ Version = '1.0.0-01' }
        ) {
            InModuleScope PSDepend -Parameters @{ Version = $Version } {
                param($Version)
                Test-PSDependPrereleaseVersion -Version $Version
            } | Should -Be $true
        }

        It 'Detects a 4-part version with a prerelease suffix, even though no real Gallery module can have one (<Version>)' -TestCases @(
            @{ Version = '1.2.3.4-beta1' }
        ) {
            InModuleScope PSDepend -Parameters @{ Version = $Version } {
                param($Version)
                Test-PSDependPrereleaseVersion -Version $Version
            } | Should -Be $true
        }
    }

    Context 'Plain (non-prerelease) versions (should not warn)' {

        It 'Does not flag a version with no dash suffix (<Version>)' -TestCases @(
            @{ Version = '1.2' }
            @{ Version = '1.2.3' }
            @{ Version = '1.2.3.4' }
        ) {
            InModuleScope PSDepend -Parameters @{ Version = $Version } {
                param($Version)
                Test-PSDependPrereleaseVersion -Version $Version
            } | Should -Be $false
        }
    }

    Context 'Invalid or out-of-scope version strings (should not warn)' {

        It 'Does not flag a bare single-component version with a dash suffix, since no real ModuleVersion has fewer than two segments (<Version>)' -TestCases @(
            @{ Version = '5-beta1' }
        ) {
            InModuleScope PSDepend -Parameters @{ Version = $Version } {
                param($Version)
                Test-PSDependPrereleaseVersion -Version $Version
            } | Should -Be $false
        }

        It 'Does not flag non-version strings (<Version>)' -TestCases @(
            @{ Version = 'latest' }
            @{ Version = '' }
            @{ Version = $null }
            @{ Version = 'not-a-version' }
        ) {
            InModuleScope PSDepend -Parameters @{ Version = $Version } {
                param($Version)
                Test-PSDependPrereleaseVersion -Version $Version
            } | Should -Be $false
        }

        It 'Does not flag NuGet range syntax, since ranges are never passed to this helper (<Version>)' -TestCases @(
            @{ Version = '[1.0.0,2.0.0)' }
            @{ Version = '[2.0,)' }
        ) {
            InModuleScope PSDepend -Parameters @{ Version = $Version } {
                param($Version)
                Test-PSDependPrereleaseVersion -Version $Version
            } | Should -Be $false
        }
    }
}
