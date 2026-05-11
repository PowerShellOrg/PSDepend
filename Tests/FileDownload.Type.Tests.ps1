#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        Set-BuildEnvironment -Path "$PSScriptRoot/.." -Force
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/FileDownload.ps1'
}

Describe 'FileDownload script' {

    BeforeAll {
        InModuleScope PSDepend {
            Mock Get-WebFile { }
            Mock Add-ToItemCollection { }
        }
    }

    It 'Downloads to Target with filename parsed from the URL when Target is an existing folder' {
        $targetDir = (New-Item 'TestDrive:/dl' -ItemType Directory -Force).FullName
        $dep = New-PSDependFixture -DependencyName 'https://example.com/sample.dll' -DependencyType 'FileDownload' -Target $targetDir
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath; T = $targetDir } {
            & $ScriptPath -Dependency $Dep
        }
        Should -Invoke -CommandName Get-WebFile -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
            $URL -eq 'https://example.com/sample.dll' -and ($Path -like "*sample.dll")
        }
    }

    It 'Uses Source to override the URL when supplied' {
        $targetDir = (New-Item 'TestDrive:/dl2' -ItemType Directory -Force).FullName
        $dep = New-PSDependFixture -DependencyName 'ignored-key' -DependencyType 'FileDownload' -Target $targetDir -Source 'https://example.com/other.dll'
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        Should -Invoke -CommandName Get-WebFile -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
            $URL -eq 'https://example.com/other.dll'
        }
    }

    It 'Skips download when the target file already exists' {
        $targetDir = (New-Item 'TestDrive:/dl3' -ItemType Directory -Force).FullName
        $existingFile = Join-Path $targetDir 'sample.dll'
        Set-Content -Path $existingFile -Value 'existing'

        $dep = New-PSDependFixture -DependencyName 'https://example.com/sample.dll' -DependencyType 'FileDownload' -Target $existingFile
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        Should -Invoke -CommandName Get-WebFile -ModuleName PSDepend -Times 0
    }

    It 'PSDependAction Test returns $true when the file exists' {
        $targetDir = (New-Item 'TestDrive:/dl4' -ItemType Directory -Force).FullName
        $existingFile = Join-Path $targetDir 'sample.dll'
        Set-Content -Path $existingFile -Value 'existing'

        $dep = New-PSDependFixture -DependencyName 'https://example.com/sample.dll' -DependencyType 'FileDownload' -Target $existingFile
        $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -PSDependAction Test
        }
        $result | Should -Be $true
    }
}
