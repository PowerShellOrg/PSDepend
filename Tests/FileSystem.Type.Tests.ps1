#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        Set-BuildEnvironment -Path "$PSScriptRoot/.." -Force
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/FileSystem.ps1'
}

Describe 'FileSystem script' {

    BeforeAll {
        InModuleScope PSDepend {
            Mock Copy-Item { }
        }
    }

    It 'Copies a file from Source to Target when hashes differ' {
        $srcDir = (New-Item 'TestDrive:/src' -ItemType Directory -Force).FullName
        $tgtDir = (New-Item 'TestDrive:/tgt' -ItemType Directory -Force).FullName
        $src = Join-Path $srcDir 'src.txt'
        Set-Content -Path $src -Value 'hello'

        $dep = New-PSDependFixture -DependencyName 'fs-file' -DependencyType 'FileSystem' -Source $src -Target $tgtDir
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        Should -Invoke -CommandName Copy-Item -ModuleName PSDepend -Times 1
    }

    It 'PSDependAction Test returns $false when target is missing' {
        $srcDir = (New-Item 'TestDrive:/src2' -ItemType Directory -Force).FullName
        $tgtDir = (New-Item 'TestDrive:/missing-tgt' -ItemType Directory -Force).FullName
        $src = Join-Path $srcDir 'src2.txt'
        Set-Content -Path $src -Value 'content'

        $dep = New-PSDependFixture -DependencyName 'fs-test' -DependencyType 'FileSystem' -Source $src -Target $tgtDir
        $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -PSDependAction Test
        }
        $result | Should -Be $false
    }

    It 'Errors and skips when Source does not exist' {
        $tgtDir = (New-Item 'TestDrive:/tgt3' -ItemType Directory -Force).FullName
        $missingSrc = Join-Path $tgtDir 'does-not-exist.txt'
        $dep = New-PSDependFixture -DependencyName 'fs-missing' -DependencyType 'FileSystem' -Source $missingSrc -Target $tgtDir

        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -ErrorAction SilentlyContinue
        }
        Should -Invoke -CommandName Copy-Item -ModuleName PSDepend -Times 0
    }
}
