#requires -Module @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

BeforeAll {
    if (-not $env:BHProjectPath) {
        Set-BuildEnvironment -Path "$PSScriptRoot/.." -Force
    }
    Remove-Module $env:BHProjectName -ErrorAction SilentlyContinue
    Import-Module (Join-Path $env:BHProjectPath $env:BHProjectName) -Force

    Import-Module (Join-Path $PSScriptRoot 'Shared/TestHelpers.psm1') -Force

    $script:ScriptPath = Join-Path $env:BHProjectPath 'PSDepend/PSDependScripts/Git.ps1'
}

Describe 'Git script' {

    BeforeAll {
        InModuleScope PSDepend {
            # Simulate `git clone <url>` by materialising the repo directory
            # under PWD so the script's subsequent `Set-Location $RepoPath`
            # succeeds. Without this, CI fails on the non-terminating error
            # from line 173 of Git.ps1.
            Mock Invoke-ExternalCommand {
                if ($Arguments -contains 'clone') {
                    $url = $Arguments | Where-Object { $_ -ne 'clone' } | Select-Object -First 1
                    if ($url) {
                        $repoName = ($url.TrimEnd('/') -split '/')[-1] -replace '\.git$', ''
                        if ($repoName -and -not (Test-Path $repoName)) {
                            $null = New-Item -ItemType Directory -Path $repoName -Force
                        }
                    }
                }
            }
            Mock Import-PSDependModule { }
            Mock Add-ToItemCollection  { }
        }
    }

    It 'Clones the repo via git when the target does not exist' {
        $targetDir = (New-Item 'TestDrive:/git-target' -ItemType Directory -Force).FullName
        $dep = New-PSDependFixture -DependencyName 'https://example.com/user/repo.git' -DependencyType 'Git' -Target $targetDir

        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        # git clone + git checkout
        Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 1 -ParameterFilter {
            $Arguments -contains 'clone'
        }
        Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 1 -ParameterFilter {
            $Arguments -contains 'checkout'
        }
    }

    It 'Converts account/repo shorthand to a GitHub URL' {
        $targetDir = (New-Item 'TestDrive:/git-target2' -ItemType Directory -Force).FullName
        $dep = New-PSDependFixture -DependencyName 'user/repo' -DependencyType 'Git' -Target $targetDir

        InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep
        }
        Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 1 -ParameterFilter {
            $Arguments -contains 'clone' -and ($Arguments -contains 'https://github.com/user/repo.git')
        }
    }

    It 'PSDependAction Test returns $false when the repo path does not exist' {
        $targetDir = (New-Item 'TestDrive:/git-test' -ItemType Directory -Force).FullName
        $dep = New-PSDependFixture -DependencyName 'https://example.com/user/repo.git' -DependencyType 'Git' -Target $targetDir

        $result = InModuleScope PSDepend -Parameters @{ Dep = $dep; ScriptPath = $script:ScriptPath } {
            & $ScriptPath -Dependency $Dep -PSDependAction Test
        }
        $result | Should -Be $false
        Should -Invoke -CommandName Invoke-ExternalCommand -ModuleName PSDepend -Times 0
    }
}
