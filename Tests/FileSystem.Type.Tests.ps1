#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force
    $script:SkipUnsupported = -not (Test-PSDependTypeSupportedHere -DependencyType 'FileSystem')
}

BeforeAll {
    if (-not $env:BHProjectPath) {
        Set-BuildEnvironment -Path "$PSScriptRoot/.." -Force
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/FileSystem.ps1'
}

Describe 'FileSystem script' -Skip:$SkipUnsupported {

    BeforeAll {
        InModuleScope PSDepend {
            Mock Copy-Item { }
        }
    }

    # Use the Pester-supplied $TestDrive filesystem path rather than the
    # 'TestDrive:' PSDrive. On Linux/macOS, (New-Item 'TestDrive:/x').FullName
    # returns a path that resolves as relative-to-PWD inside the dependency
    # script, breaking Get-Hash.

    It 'Copies a file from Source to Target when hashes differ' {
        $srcDir = Join-Path $TestDrive 'src'
        $tgtDir = Join-Path $TestDrive 'tgt'
        $null = New-Item -ItemType Directory -Path $srcDir, $tgtDir -Force
        $src = Join-Path $srcDir 'src.txt'
        Set-Content -Path $src -Value 'hello'

        $dep = New-PSDependFixture -DependencyName 'fs-file' -DependencyType 'FileSystem' -Source $src -Target $tgtDir
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        Should -Invoke -CommandName Copy-Item -ModuleName PSDepend -Times 1
    }

    It 'PSDependAction Test returns $false when the target file is missing from the target directory' {
        $srcDir = Join-Path $TestDrive 'src2'
        $tgtDir = Join-Path $TestDrive 'missing-tgt'
        $null = New-Item -ItemType Directory -Path $srcDir, $tgtDir -Force
        $src = Join-Path $srcDir 'src2.txt'
        Set-Content -Path $src -Value 'content'

        $dep = New-PSDependFixture -DependencyName 'fs-test' -DependencyType 'FileSystem' -Source $src -Target $tgtDir
        $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -PSDependAction Test
        }
        $result | Should -Be $false
    }

    It 'Errors and skips when Source does not exist' {
        $tgtDir = Join-Path $TestDrive 'tgt3'
        $null = New-Item -ItemType Directory -Path $tgtDir -Force
        $missingSrc = Join-Path $tgtDir 'does-not-exist.txt'
        $dep = New-PSDependFixture -DependencyName 'fs-missing' -DependencyType 'FileSystem' -Source $missingSrc -Target $tgtDir

        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -ErrorAction SilentlyContinue
        }
        Should -Invoke -CommandName Copy-Item -ModuleName PSDepend -Times 0
    }
}
