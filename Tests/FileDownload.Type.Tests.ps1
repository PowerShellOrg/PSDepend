#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeDiscovery {
    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force
    $script:SkipUnsupported = -not (Test-PSDependTypeSupportedHere -DependencyType 'FileDownload')
}

BeforeAll {
    if (-not $env:BHProjectPath) {
        & "$PSScriptRoot\..\build.ps1" -Task 'Build'
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/FileDownload.ps1'
}

Describe 'FileDownload script' -Skip:$SkipUnsupported {

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

    It 'Creates a new directory and downloads into it when Target has no extension and does not exist' {
        $base = (New-Item 'TestDrive:/dl5base' -ItemType Directory -Force).FullName
        $newDir = Join-Path $base 'newcontainer'
        # Trailing separator signals "this is a container, not an extensionless file"
        $dep = New-PSDependFixture -DependencyName 'https://example.com/sample.dll' -DependencyType 'FileDownload' -Target "$newDir/"
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath; T = $newDir } {
            & $ScriptPath -Dependency $Dep
        }
        Should -Invoke -CommandName Get-WebFile -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
            $URL -eq 'https://example.com/sample.dll' -and ($Path -like "*newcontainer*sample.dll")
        }
        Test-Path $newDir -PathType Container | Should -Be $true
    }

    It 'Treats Target as a full file path when it has a file extension and parent exists' {
        $targetDir = (New-Item 'TestDrive:/dl6' -ItemType Directory -Force).FullName
        $targetFile = Join-Path $targetDir 'out.dll'
        $dep = New-PSDependFixture -DependencyName 'https://example.com/other.dll' -DependencyType 'FileDownload' -Target $targetFile
        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        Should -Invoke -CommandName Get-WebFile -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
            $URL -eq 'https://example.com/other.dll' -and $Path -eq $targetFile
        }
    }

    It 'Roots a relative Target against $PWD and downloads to it' {
        $baseDir = (New-Item 'TestDrive:/relbase' -ItemType Directory -Force).FullName
        Push-Location $baseDir
        try {
            # Trailing separator signals "this is a container, not an extensionless file"
            $dep = New-PSDependFixture -DependencyName 'https://example.com/sample.dll' -DependencyType 'FileDownload' -Target 'subdir/'
            InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
                & $ScriptPath -Dependency $Dep
            }
            Should -Invoke -CommandName Get-WebFile -ModuleName PSDepend -Times 1 -Exactly -ParameterFilter {
                $Path -like "*subdir*sample.dll"
            }
        }
        finally {
            Pop-Location
        }
    }
}
