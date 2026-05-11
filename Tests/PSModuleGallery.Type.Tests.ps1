BeforeDiscovery {
    if ($null -eq $env:BHPSModuleManifest) {
        & "$PSScriptRoot/../Build.ps1" -Task Init
    }
    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Output'
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputModVerManifest = Join-Path -Path $outputModVerDir -ChildPath "$($env:BHProjectName).psd1"

    Get-Module $env:BHProjectName | Remove-Module -Force -ErrorAction Ignore
    Import-Module -Name $outputModVerManifest -Verbose:$false -ErrorAction Stop

    if($IsLinux -or $IsMacOS) {
        # Skip tests tagged WindowsOnly on non-Windows platforms
        $nonWindows = $true
    }
    $PSVersion = $PSVersionTable.PSVersion.Major
}

Describe "PSModuleGallery Type" -Tag 'Integration' {
    BeforeAll {
        $script:TestDepends = Join-Path $ENV:BHProjectPath "Tests/DependFiles"
        $script:ProjectRoot = $ENV:BHProjectPath
        $script:ExistingPSModulePath = $env:PSModulePath.PSObject.Copy()
        $script:ExistingPath = $env:PATH.PSObject.Copy()

        $script:Password = 'testPassword' | ConvertTo-SecureString -AsPlainText -Force
        $script:TestCredential = New-Object System.Management.Automation.PSCredential('testUser', $script:Password)
        $script:OtherCredential = New-Object System.Management.Automation.PSCredential('otherUser', $script:Password)
        $script:Credentials = @{
            'imaginaryCreds' = $script:TestCredential
            'otherCreds' = $script:OtherCredential
        }

        $script:Verbose = @{}
        if($ENV:BHBranchName -notlike "master" -or $env:BHCommitMessage -match "!verbose") {
            $script:Verbose.add("Verbose",$True)
        }
    }

    Describe "PSGalleryModule Type PS$PSVersion" {
        BeforeAll {
            $script:SavePath = (New-Item 'TestDrive:/PSDependPesterTest' -ItemType Directory -Force).FullName
        }

        Context 'Installs Modules' {
            BeforeAll {
                Mock Install-Module { return $true } -ModuleName PSDepend
                $script:Results = Invoke-PSDepend @Verbose -Path "$TestDepends/psgallerymodule.depend.psd1" -Force
            }

            It 'Should execute Install-Module' {
                Should -Invoke Install-Module -Times 1 -Exactly -Scope Context -ModuleName PSDepend
            }

            It 'Should Return Mocked output' {
                $script:Results | Should -Be $True
            }
        }

        Context 'Installs Modules with credentials' {
            BeforeAll {
                Mock Install-Module { return $true } -ModuleName PSDepend
                $script:Results = Invoke-PSDepend @Verbose -Path "$TestDepends/psgallerymodule.withcredentials.depend.psd1" -Force -Credentials $Credentials
            }

            It 'Should execute Install-Module' {
                Should -Invoke Install-Module -Times 1 -Exactly -ParameterFilter { $Credential -ne $null -and $Credential.Username -eq 'testUser' } -Scope Context -ModuleName PSDepend
            }

            It 'Should Return Mocked output' {
                $script:Results | Should -Be $True
            }
        }

        Context 'Installs Modules with multiple credentials' {
            BeforeAll {
                Mock Install-Module { return $true } -ModuleName PSDepend
                $script:Results = Invoke-PSDepend @Verbose -Path "$TestDepends/psgallerymodule.multiplecredentials.depend.psd1" -Force -Credentials $Credentials
            }

            It 'Should execute Install-Module with the correct credentials' {
                Should -Invoke Install-Module -Times 1 -Exactly -ParameterFilter { $Name -eq 'imaginary' -and $Credential -ne $null -and $Credential.Username -eq 'testUser' } -Scope Context -ModuleName PSDepend
                Should -Invoke Install-Module -Times 1 -Exactly -ParameterFilter { $Name -eq 'other' -and $Credential -ne $null -and $Credential.Username -eq 'otherUser' } -Scope Context -ModuleName PSDepend
            }

            It 'Should Return Mocked output' {
                $script:Results | Should -Be @($True, $True)
            }
        }

        Context 'Saves Modules' {
            BeforeAll {
                Mock Save-Module { return $true } -ModuleName PSDepend
                $script:Results = Invoke-PSDepend @Verbose -Path "$TestDepends/savemodule.depend.psd1" -Force
            }

            It 'Should execute Save-Module' {
                Should -Invoke Save-Module -Times 1 -Exactly -Scope Context -ModuleName PSDepend
            }

            It 'Should Return Mocked output' {
                $script:Results | Should -Be $True
            }
        }

        Context 'Saves Modules with credentials' {
            BeforeAll {
                Mock Save-Module { return $true } -ModuleName PSDepend
                $script:Results = Invoke-PSDepend @Verbose -Path "$TestDepends/savemodule.withcredentials.depend.psd1" -Force -Credentials $Credentials
            }

            It 'Should execute Save-Module' {
                Should -Invoke Save-Module -Times 1 -Exactly -ParameterFilter { $Credential -ne $null -and $Credential.Username -eq 'testUser' } -Scope Context -ModuleName PSDepend
            }

            It 'Should Return Mocked output' {
                $script:Results | Should -Be $True
            }
        }

        Context 'Repository does not Exist' {
            BeforeAll {
                Mock Install-Module { throw "Unable to find repository 'Blah'" } -ParameterFilter { $Repository -eq 'Blah' } -ModuleName PSDepend
            }

            It 'Throws because Repository could not be found' {
                $Results = { Invoke-PSDepend @Verbose -Path "$TestDepends/psgallerymodule.missingrepo.depend.psd1" -Force -ErrorAction Stop }
                $Results | Should -Throw
            }
        }

        Context 'Same module version exists (Version)' {
            BeforeAll {
                Mock Install-Module {} -ModuleName PSDepend
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                } -ModuleName PSDepend
                Mock Find-Module -ModuleName PSDepend
            }

            It 'Skips Install-Module' {
                Invoke-PSDepend @Verbose -Path "$TestDepends/psgallerymodule.sameversion.depend.psd1" -Force -ErrorAction Stop

                Should -Invoke Get-Module -Times 1 -Exactly -ModuleName PSDepend
                Should -Invoke Find-Module -Times 0 -Exactly -ModuleName PSDepend
                Should -Invoke Install-Module -Times 0 -Exactly -ModuleName PSDepend
            }
        }

        Context 'Same module version exists (SemVersion)' {
            BeforeAll {
                Mock Install-Module {} -ModuleName PSDepend
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.5-preview0002'
                    }
                } -ModuleName PSDepend
                Mock Find-Module -ModuleName PSDepend
            }

            It 'Skips Install-Module' {
                Invoke-PSDepend @Verbose -Path "$TestDepends/psgallerymodule.SameSemanticVersion.depend.psd1" -Force -ErrorAction Stop

                Should -Invoke Get-Module -Times 1 -Exactly -ModuleName PSDepend
                Should -Invoke Find-Module -Times 0 -Exactly -ModuleName PSDepend
                Should -Invoke Install-Module -Times 0 -Exactly -ModuleName PSDepend
            }
        }

        Context 'Latest module required, and already installed (version)' {
            BeforeAll {
                Mock Install-Module {} -ModuleName PSDepend
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                } -ModuleName PSDepend
                Mock Find-Module {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                } -ModuleName PSDepend
            }

            It 'Skips Install-Module' {
                Invoke-PSDepend @Verbose -Path "$TestDepends/psgallerymodule.latestversion.depend.psd1" -Force -ErrorAction Stop

                Should -Invoke Get-Module -Times 1 -Exactly -ModuleName PSDepend
                Should -Invoke Find-Module -Times 1 -Exactly -ModuleName PSDepend
                Should -Invoke Install-Module -Times 0 -Exactly -ModuleName PSDepend
            }
        }

        Context 'Latest module required, and already installed (SemVersion)' {
            BeforeAll {
                Mock Install-Module {} -ModuleName PSDepend
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.5-preview0002'
                    }
                } -ModuleName PSDepend
                Mock Find-Module {
                    [pscustomobject]@{
                        Version = '1.2.5-preview0002'
                    }
                } -ModuleName PSDepend
            }

            It 'Skips Install-Module' {
                Invoke-PSDepend @Verbose -Path "$TestDepends/psgallerymodule.latestversion.depend.psd1" -Force -ErrorAction Stop

                Should -Invoke Get-Module -Times 1 -Exactly -ModuleName PSDepend
                Should -Invoke Find-Module -Times 1 -Exactly -ModuleName PSDepend
                Should -Invoke Install-Module -Times 0 -Exactly -ModuleName PSDepend
            }
        }

        Context 'Test-Dependency' {

            BeforeEach {
                Mock Install-Module {} -ModuleName PSDepend
                Mock Find-Module {} -ModuleName PSDepend
            }

            It 'Returns $true when it finds an existing module (Version)' {
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                } -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.sameversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $True
            }

            It 'Returns $true when it finds an existing module (SemVersion)' {
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.5-preview0002'
                    }
                } -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.SameSemanticVersion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $True
            }

            It 'Returns $true when it finds an existing latest module (Version)' {
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                } -ModuleName PSDepend
                Mock Find-Module {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                } -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.latestversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $True
            }

            It 'Returns $true when it finds an existing latest module (SemVersion)' {
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.5-preview0002'
                    }
                } -ModuleName PSDepend
                Mock Find-Module {
                    [pscustomobject]@{
                        Version = '1.2.5-preview0002'
                    }
                } -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.latestversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $True
            }

            It "Returns `$false when it doesn't find an existing module (Version)" {
                Mock Get-Module { $null } -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.sameversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $False
            }

            It "Returns `$false when it doesn't find an existing module (SemVersion)" {
                Mock Get-Module { $null } -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.SameSemanticVersion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $False
            }

            It "Returns `$false when it finds an existing module with a lower version (Version)" {
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.4'
                    }
                } -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.sameversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $False
            }

            It 'Returns $false when it finds an existing module with a lower version (SemVersion)' {
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.5-preview0001'
                    }
                } -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.SameSemanticVersion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $False
            }

            It 'Returns $false when it finds an existing module with a lower version (SemVersion-Version)' {
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.4'
                    }
                } -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.SameSemanticVersion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $False
            }

            It 'Returns $false when it finds an existing module with a lower version than latest (Version)' {
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.4'
                    }
                } -ModuleName PSDepend
                Mock Find-Module {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                } -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.latestversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $False
            }

            It 'Returns $false when it finds an existing module with a lower version than latest (SemVersion)' {
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.5-preview0001'
                    }
                } -ModuleName PSDepend
                Mock Find-Module {
                    [pscustomobject]@{
                        Version = '1.2.5-preview0002'
                    }
                } -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.latestversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $False
            }
        }

        Context 'Imports dependencies' {
            BeforeAll {
                Mock Install-Module {} -ModuleName PSDepend
                Mock Import-Module -ModuleName PSDepend
            }

            It 'Runs Import-Module when import is specified' {
                $Results = Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.depend.psd1" | Import-Dependency @Verbose
                Should -Invoke Import-Module -Times 1 -Exactly -Scope Context -ModuleName PSDepend
                Should -Invoke Install-Module -Times 0 -Exactly -Scope Context -ModuleName PSDepend
            }
        }

        Context 'AddToPath on install of module to target folder' {
            BeforeAll {
                Mock Save-Module { $True } -ModuleName PSDepend
            }

            AfterEach {
                $ENV:PSModulePath = $script:ExistingPSModulePath
            }

            It 'Adds folder to path' {
                Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerymodule.addtopath.depend.psd1" -Force -ErrorAction Stop
                ($env:PSModulePath -split ([IO.Path]::PathSeparator)) -contains $script:SavePath | Should -Be $True
            }
        }

        Context 'AddToPath on import of module in target folder' {

            $addToPathTestCases = @(
                @{
                    Version = 'specific version'
                    DependPsd1File = "psgallerymodule.addtopath.depend.psd1"
                },
                @{
                    Version = 'latest version'
                    DependPsd1File = "psgallerymodule.latestaddtopath.depend.psd1"
                }
            )

            BeforeAll {
                Mock Install-Module -ModuleName PSDepend
                Mock Import-Module -ModuleName PSDepend
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                } -ModuleName PSDepend
                Mock Find-Module {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                } -ModuleName PSDepend
            }

            AfterEach {
                $ENV:PSModulePath = $ExistingPSModulePath
            }

            It 'adds folder to path for <Version>' -TestCases $addToPathTestCases {
                param($DependPsd1File)

                # when
                Invoke-PSDepend @Verbose -Path "$TestDepends\$DependPsd1File" -Import -Force -ErrorAction Stop

                # check assumption that expected code path was followed...
                Should -Invoke Install-Module -Times 0 -Exactly -ModuleName PSDepend
                Should -Invoke Import-Module -Times 1 -Exactly -ModuleName PSDepend

                # then
                ($env:PSModulePath -split ([IO.Path]::PathSeparator)) -contains $script:SavePath | Should -Be $True
            }
        }

        Context 'SkipPublisherCheck' {
            BeforeAll {
                Mock Get-PSRepository { return $true } -ModuleName PSDepend
                Mock Install-Module {} -ModuleName PSDepend
            }

            It 'Supplies SkipPublisherCheck switch to Install-Module' {
                Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerymodule.skippubcheck.depend.psd1" -Force -ErrorAction Stop
                Should -Invoke Install-Module -Times 1 -Exactly -Scope Context -ModuleName PSDepend
                Should -Invoke Install-Module -Times 1 -Exactly -Scope Context -ModuleName PSDepend -ParameterFilter {
                    $SkipPublisherCheck -eq $true
                }
            }
        }

        Context 'AllowPrerelease' {
            BeforeAll {
                Mock Get-PSRepository { return $true } -ModuleName PSDepend
                Mock Install-Module {} -ModuleName PSDepend
            }

            It 'Supplies AllowPrerelease switch to Install-Module' {
                Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerymodule.AllowPrerelease.depend.psd1" -Force -ErrorAction Stop
                Should -Invoke Install-Module -Times 1 -Exactly -Scope Context -ModuleName PSDepend
                Should -Invoke Install-Module -Times 1 -Exactly -Scope Context -ModuleName PSDepend -ParameterFilter {
                    $AllowPrerelease -eq $true
                }
            }
        }
    }

    Describe "Git Type PS$PSVersion" -Skip:$nonWindows {
        BeforeAll {
            $script:SavePath = (New-Item 'TestDrive:/PSDependPesterTest' -ItemType Directory -Force).FullName
        }

        Context 'Installs Module' {
            BeforeAll {
                Mock Invoke-ExternalCommand {
                    [pscustomobject]@{
                        PSB = $PSBoundParameters
                        Arg = $Args
                    }
                } -ModuleName PSDepend -ParameterFilter { $Arguments -contains 'checkout' -or $Arguments -contains 'clone' }
                Mock New-Item { return $true } -ModuleName PSDepend
                Mock Push-Location {} -ModuleName PSDepend
                Mock Pop-Location {} -ModuleName PSDepend
                Mock Set-Location {} -ModuleName PSDepend
                Mock Test-Path { return $False } -ModuleName PSDepend -ParameterFilter { $Path -match "Invoke-Build$|PSDeploy$" }

                $script:Dependencies = Get-Dependency @Verbose -Path "$TestDepends\git.depend.psd1"
                $script:Results = Invoke-PSDepend @Verbose -Path "$TestDepends\git.depend.psd1" -Force
            }

            It 'Parses the Git dependency type' {
                $script:Dependencies.count | Should -Be 3
                ( $script:Dependencies | Where-Object { $_.DependencyType -eq 'Git' } ).Count | Should -Be 3
                ( $script:Dependencies | Where-Object { $_.DependencyName -like '*nightroman/Invoke-Build' }).Version | Should -Be 'ac54571010d8ca5107fc8fa1a69278102c9aa077'
                ( $script:Dependencies | Where-Object { $_.DependencyName -like '*ramblingcookiemonster/PSDeploy' }).Version | Should -Be 'master'
            }

            It 'Invokes the Git dependency type' {
                Should -Invoke Invoke-ExternalCommand -Times 6 -Exactly -Scope Context -ModuleName PSDepend
            }
        }

        Context 'Tests dependency' {
            BeforeAll {
                Mock New-Item { return $true } -ModuleName PSDepend
                Mock Push-Location {} -ModuleName PSDepend
                Mock Pop-Location {} -ModuleName PSDepend
                Mock Set-Location {} -ModuleName PSDepend
                Mock Invoke-ExternalCommand -ModuleName PSDepend -ParameterFilter { $Arguments -contains 'checkout' -or $Arguments -contains 'clone' }
            }

            It 'Returns $false if git repo does not exist' {
                Mock Test-Path { return $False } -ModuleName PSDepend -ParameterFilter { $Path -match "PSDeploy$" }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\git.test.depend.psd1" | Test-Dependency @Verbose -Quiet )
                $Results.count | Should -Be 1
                $Results[0] | Should -Be $False
            }

            It 'Returns $true if git repo does exist' {
                Mock Test-Path { return $true } -ModuleName PSDepend -ParameterFilter { $Path -match "PSDeploy$" }
                Mock Invoke-ExternalCommand { return 'imaginary_branch' } -ModuleName PSDepend -ParameterFilter { $Arguments -contains 'rev-parse' }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\git.test.depend.psd1" | Test-Dependency @Verbose -Quiet )
                $Results.count | Should -Be 1
                $Results[0] | Should -Be $true
            }
        }
    }

    Describe "FileDownload Type PS$PSVersion" -Skip:$nonWindows {
        BeforeAll {
            $script:SavePath = (New-Item 'TestDrive:/PSDependPesterTest' -ItemType Directory -Force).FullName
        }

        Context 'Installs dependency' {
            BeforeAll {
                Mock Get-WebFile {
                    [pscustomobject]@{
                        PSB = $PSBoundParameters
                        Arg = $Args
                    }
                } -ModuleName PSDepend
                $script:Dependencies = @(Get-Dependency @Verbose -Path "$TestDepends\filedownload.depend.psd1")
            }

            It 'Parses the FileDownload dependency type' {
                $script:Dependencies.count | Should -Be 1
                $script:Dependencies[0].DependencyType | Should -Be 'FileDownload'
            }

            It 'Invokes the FileDownload dependency type' {
                Invoke-PSDepend @Verbose -Path "$TestDepends\filedownload.depend.psd1" -Force
                Should -Invoke Get-WebFile -Times 1 -Exactly -ModuleName PSDepend
            }

            It 'Parses URL file name and skips on existing' {
                New-Item -ItemType File -Path (Join-Path $script:SavePath 'System.Data.SQLite.dll') -Force
                Invoke-PSDepend @Verbose -Path "$TestDepends\filedownload.depend.psd1" -Force
                Should -Invoke Get-WebFile -Times 0 -Exactly -ModuleName PSDepend
            }
        }

        Context 'Tests dependency' {
            BeforeAll {
                Remove-Item $script:SavePath -Force -Recurse -ErrorAction SilentlyContinue
                $null = New-Item $script:SavePath -ItemType Directory -Force
            }

            It 'Returns $false if file does not exist' {
                Mock Get-WebFile {} -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\filedownload.depend.psd1" | Test-Dependency @Verbose -Quiet)
                $Results.count | Should -Be 1
                $Results[0] | Should -Be $False
                Should -Invoke Get-WebFile -Times 0 -Exactly -ModuleName PSDepend
            }

            It 'Returns $true if file does exist' {
                New-Item -ItemType File -Path (Join-Path $script:SavePath 'System.Data.SQLite.dll') -Force
                Mock Get-WebFile {} -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\filedownload.depend.psd1" | Test-Dependency @Verbose -Quiet)
                $Results.count | Should -Be 1
                $Results[0] | Should -Be $true
                Should -Invoke Get-WebFile -Times 0 -Exactly -ModuleName PSDepend
            }
        }
    }

    Describe "PSGalleryNuget Type PS$PSVersion" -Skip:$nonWindows {
        BeforeAll {
            $script:SavePath = (New-Item 'TestDrive:/PSDependPesterTest' -ItemType Directory -Force).FullName
        }

        Context 'Installs Modules' {
            BeforeAll {
                Mock Test-Path { return $true } -ModuleName PSDepend -ParameterFilter { $PathType -eq 'Container' }
                Mock Invoke-ExternalCommand { return $true } -ModuleName PSDepend
                Mock Find-NugetPackage { return $true } -ModuleName PSDepend
                $script:Results = Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerynuget.depend.psd1" -Force
            }

            It 'Should execute Invoke-ExternalCommand' {
                Should -Invoke Invoke-ExternalCommand -Times 1 -Exactly -Scope Context -ModuleName PSDepend
            }

            It 'Should Return Mocked output' {
                $script:Results | Should -Be $True
            }
        }

        Context 'Same module version exists' {
            BeforeAll {
                Mock Test-Path { return $True } -ModuleName PSDepend -ParameterFilter { $Path -match 'jenkins' }
                Mock Invoke-ExternalCommand {} -ModuleName PSDepend
                Mock Import-LocalizedData {
                    [pscustomobject]@{
                        ModuleVersion = '1.2.5'
                    }
                } -ModuleName PSDepend -ParameterFilter { $FileName -eq 'jenkins.psd1' }
                Mock Find-NugetPackage -ModuleName PSDepend
            }

            It 'Skips Invoke-ExternalCommand' {
                Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerynuget.sameversion.depend.psd1" -Force -ErrorAction Stop

                Should -Invoke Import-LocalizedData -Times 1 -Exactly -ModuleName PSDepend
                Should -Invoke Find-NugetPackage -Times 0 -Exactly -ModuleName PSDepend
                Should -Invoke Invoke-ExternalCommand -Times 0 -Exactly -ModuleName PSDepend
            }
        }

        Context 'Latest module required, and already installed' {
            BeforeAll {
                Mock Test-Path { return $True } -ModuleName PSDepend -ParameterFilter { $Path -match 'jenkins' }
                Mock Invoke-ExternalCommand {} -ModuleName PSDepend
                Mock Import-LocalizedData {
                    [pscustomobject]@{
                        ModuleVersion = '1.2.5'
                    }
                } -ModuleName PSDepend -ParameterFilter { $FileName -eq 'jenkins.psd1' }
                Mock Find-NugetPackage {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                } -ModuleName PSDepend
            }

            It 'Skips Invoke-ExternalCommand' {
                Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerynuget.latestversion.depend.psd1" -Force -ErrorAction Stop

                Should -Invoke Import-LocalizedData -Times 1 -Exactly -ModuleName PSDepend
                Should -Invoke Find-NugetPackage -Times 1 -Exactly -ModuleName PSDepend
                Should -Invoke Invoke-ExternalCommand -Times 0 -Exactly -ModuleName PSDepend
            }
        }

        Context 'Tests dependencies' {

            BeforeEach {
                Mock Invoke-ExternalCommand {} -ModuleName PSDepend
                Mock Test-Path { return $True } -ModuleName PSDepend -ParameterFilter { $Path -match 'jenkins' }
                Mock Find-NugetPackage {} -ModuleName PSDepend
            }

            It 'Returns $true when it finds an existing module' {
                Mock Import-LocalizedData {
                    [pscustomobject]@{
                        ModuleVersion = '1.2.5'
                    }
                } -ModuleName PSDepend -ParameterFilter { $FileName -eq 'jenkins.psd1' }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\psgallerynuget.sameversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $True
            }

            It 'Returns $true when it finds an existing latest module' {
                Mock Import-LocalizedData {
                    [pscustomobject]@{
                        ModuleVersion = '1.2.5'
                    }
                } -ModuleName PSDepend -ParameterFilter { $FileName -eq 'jenkins.psd1' }
                Mock Find-NugetPackage {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                } -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\psgallerynuget.latestversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $True
            }

            It "Returns `$false when it doesn't find an existing module" {
                Mock Import-LocalizedData -ModuleName PSDepend -ParameterFilter { $FileName -eq 'jenkins.psd1' }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\psgallerynuget.sameversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $False
            }

            It "Returns `$false when it finds an existing module with a lower version" {
                Mock Import-LocalizedData {
                    [pscustomobject]@{
                        ModuleVersion = '1.2.4'
                    }
                } -ModuleName PSDepend -ParameterFilter { $FileName -eq 'jenkins.psd1' }

                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\psgallerynuget.sameversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $False
            }

            It "Returns `$false when it finds an existing module with a lower version than latest" {
                Mock Import-LocalizedData {
                    [pscustomobject]@{
                        ModuleVersion = '1.2.4'
                    }
                } -ModuleName PSDepend -ParameterFilter { $FileName -eq 'jenkins.psd1' }
                Mock Find-NugetPackage {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                } -ModuleName PSDepend

                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\psgallerynuget.latestversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $False
            }
        }

        Context 'Imports dependencies' {
            BeforeAll {
                Mock Invoke-ExternalCommand { $True } -ModuleName PSDepend
                Mock Import-Module -ModuleName PSDepend
            }

            It 'Runs Import-Module when import is specified' {
                $Results = Get-Dependency @Verbose -Path "$TestDepends\psgallerynuget.depend.psd1" | Import-Dependency @Verbose
                Should -Invoke Import-Module -Times 1 -Exactly -Scope Context -ModuleName PSDepend
                Should -Invoke Invoke-ExternalCommand -Times 0 -Exactly -Scope Context -ModuleName PSDepend
            }
        }

        Context 'AddToPath on install of module to target folder' {
            BeforeAll {
                Mock Invoke-ExternalCommand { $True } -ModuleName PSDepend
                Mock Import-Module -ModuleName PSDepend
            }

            AfterEach {
                $ENV:PSModulePath = $script:ExistingPSModulePath
            }

            It 'Adds folder to path' {
                $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerynuget.addtopath.depend.psd1" -Force -ErrorAction Stop
                $env:PSModulePath -split ([IO.Path]::PathSeparator) -contains $script:SavePath | Should -Be $True
            }
        }

        Context 'AddToPath on import of module in target folder' {

            $addToPathTestCases = @(
                @{
                    Version = 'specific version'
                    DependPsd1File = "psgallerynuget.addtopath.depend.psd1"
                },
                @{
                    Version = 'latest version'
                    DependPsd1File = "psgallerynuget.latestaddtopath.depend.psd1"
                }
            )

            BeforeAll {
                Mock Test-Path { return $True } -ModuleName PSDepend -ParameterFilter { $Path -match 'imaginary' }
                Mock Invoke-ExternalCommand {} -ModuleName PSDepend
                Mock Import-Module -ModuleName PSDepend
                Mock Import-LocalizedData {
                    [pscustomobject]@{
                        ModuleVersion = '1.2.5'
                    }
                } -ModuleName PSDepend -ParameterFilter { $FileName -eq 'imaginary.psd1' }
                Mock Find-NugetPackage {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                } -ModuleName PSDepend
            }

            AfterEach {
                $ENV:PSModulePath = $ExistingPSModulePath
            }

            It 'adds folder to path for <Version>' -TestCases $addToPathTestCases {
                param($DependPsd1File)

                # when
                Invoke-PSDepend @Verbose -Path "$TestDepends\$DependPsd1File" -Import -Force -ErrorAction Stop

                # check assumption that expected code path was followed...
                Should -Invoke Invoke-ExternalCommand -Times 0 -Exactly -ModuleName PSDepend
                Should -Invoke Import-Module -Times 1 -Exactly -ModuleName PSDepend

                # then
                (($env:PSModulePath -split ([IO.Path]::PathSeparator))) -contains $script:SavePath | Should -Be $True
            }
        }
    }

    Describe "FileSystem Type PS$PSVersion" -Skip:$nonWindows {
        BeforeAll {
            $script:SavePath = (New-Item 'TestDrive:/PSDependPesterTest' -ItemType Directory -Force).FullName
        }

        Context 'Installs dependency' {
            BeforeAll {
                Mock Copy-Item -ModuleName PSDepend
                $script:Dependencies = @(Get-Dependency @Verbose -Path "$TestDepends\filesystem.depend.psd1")
            }

            It 'Parses the FileDownload dependency type' {
                $script:Dependencies.count | Should -Be 1
                $script:Dependencies[0].DependencyType | Should -Be 'FileSystem'
            }

            It 'Invokes the FileSystem dependency type' {
                Invoke-PSDepend @Verbose -Path "$TestDepends\filesystem.depend.psd1" -Force
                Should -Invoke Copy-Item -Times 1 -Exactly -ModuleName PSDepend
            }

            It 'Still copies if file hashes do not match' {
                New-Item -ItemType File -Path (Join-Path $script:SavePath 'notepad.exe') -Force
                Invoke-PSDepend @Verbose -Path "$TestDepends\filesystem.depend.psd1" -Force
                Should -Invoke Copy-Item -Times 1 -Exactly -ModuleName PSDepend
            }
        }

        Context 'Tests dependency' {
            BeforeAll {
                Remove-Item $script:SavePath -Force -Recurse -ErrorAction SilentlyContinue
                $null = New-Item $script:SavePath -ItemType Directory -Force
            }

            It 'Returns $false if file does not exist' {
                Mock Copy-Item -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\filesystem.depend.psd1" | Test-Dependency @Verbose -Quiet)
                $Results.count | Should -Be 1
                $Results[0] | Should -Be $False
                Should -Invoke Copy-Item -Times 0 -Exactly -ModuleName PSDepend
            }

            It 'Returns $true if file does exist' {
                xcopy C:\Windows\notepad.exe $(Join-Path $script:SavePath '*') /Y
                Mock Copy-Item -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\filesystem.depend.psd1" | Test-Dependency @Verbose -Quiet)
                $Results.count | Should -Be 1
                $Results[0] | Should -Be $true
                Should -Invoke Copy-Item -Times 0 -Exactly -ModuleName PSDepend
            }
        }
    }

    Describe "Package Type PS$PSVersion" -Tag pkg {
        BeforeAll {
            $script:SavePath = (New-Item 'TestDrive:/PSDependPesterTest' -ItemType Directory -Force).FullName

            # Inject stub functions into PSDepend's module scope so Pester generates
            # mock proxies from these simple param signatures instead of the real
            # PackageManagement/AnyPackage cmdlets (whose multi-parameter-set definitions
            # cause ParameterBindingException when called with our test splats).
            # NOTE: 'script:' qualifier is required — without it, the function is created
            # in a temporary scope that vanishes when the scriptblock returns.
            & (Get-Module PSDepend) {
                function script:Get-Package     { [cmdletbinding()]param($ProviderName, $Name, $RequiredVersion) }
                function script:Install-Package { [cmdletbinding()]param($Source, $Name, $RequiredVersion, $Force) }
                function script:Find-Package    { [cmdletbinding()]param($Name, $Source) }
                function script:Get-PackageSource { [cmdletbinding()]param() }
            }
        }

        AfterAll {
            & (Get-Module PSDepend) {
                Remove-Item Function:\Get-Package, Function:\Install-Package, Function:\Find-Package, Function:\Get-PackageSource -ErrorAction SilentlyContinue
            }
        }

        Context 'Installs Packages' {
            BeforeAll {
                Mock Get-PackageSource { @([pscustomobject]@{Name = 'chocolatey'; ProviderName = 'chocolatey'}) } -ModuleName PSDepend
                Mock Get-Package -ModuleName PSDepend
                Mock Install-Package { $True } -ModuleName PSDepend
                $script:Results = Invoke-PSDepend @Verbose -Path "$TestDepends\package.depend.psd1" -Force
            }

            It 'Should execute Install-Package' {
                Should -Invoke Install-Package -Times 1 -Exactly -Scope Context -ModuleName PSDepend
            }

            It 'Should Return Mocked output' {
                $script:Results | Should -Be $True
            }
        }
        Context 'PackageSource does not Exist' {
            BeforeAll {
                Mock Install-Package -ModuleName PSDepend
                Mock Get-PackageSource -ModuleName PSDepend
            }

            It 'Throws because Repository could not be found' {
                $Results = { Invoke-PSDepend @Verbose -Path "$TestDepends\package.depend.psd1" -Force -ErrorAction Stop }
                $Results | Should -Throw
            }
        }

        Context 'Same package version exists' {
            BeforeAll {
                Mock Get-PackageSource { @([pscustomobject]@{Name = 'chocolatey'; ProviderName = 'chocolatey'}) } -ModuleName PSDepend
                Mock Install-Package -ModuleName PSDepend
                Mock Get-Package {
                    [pscustomobject]@{
                        Version = '1.1'
                    }
                } -ModuleName PSDepend
                Mock Find-Package -ModuleName PSDepend
            }

            It 'Skips Install-Package' {
                Invoke-PSDepend @Verbose -Path "$TestDepends\package.sameversion.depend.psd1" -Force -ErrorAction Stop

                Should -Invoke Get-Package -Times 1 -Exactly -Scope Context -ModuleName PSDepend
                Should -Invoke Find-Package -Times 0 -Exactly -Scope Context -ModuleName PSDepend
                Should -Invoke Install-Package -Times 0 -Exactly -Scope Context -ModuleName PSDepend
            }
        }

        Context 'Latest package required, and already installed' {
            BeforeAll {
                Mock Get-PackageSource { @([pscustomobject]@{Name = 'chocolatey'; ProviderName = 'chocolatey'}) } -ModuleName PSDepend
                Mock Install-Package -ModuleName PSDepend
                Mock Get-Package {
                    [pscustomobject]@{
                        Version = '1.1'
                    }
                } -ModuleName PSDepend
                Mock Find-Package {
                    [pscustomobject]@{
                        Version = '1.1'
                    }
                } -ModuleName PSDepend
            }

            It 'Runs Get-Package and Find-Package, skips Install-Package' {
                Invoke-PSDepend @Verbose -Path "$TestDepends\package.latestversion.depend.psd1" -Force -ErrorAction Stop

                Should -Invoke Get-Package -Times 1 -Exactly -Scope Context -ModuleName PSDepend
                Should -Invoke Find-Package -Times 1 -Exactly -Scope Context -ModuleName PSDepend
                Should -Invoke Install-Package -Times 0 -Exactly -Scope Context -ModuleName PSDepend
            }
        }

        Context 'Test-Dependency' {
            BeforeEach {
                Mock Get-PackageSource { @([pscustomobject]@{Name = 'chocolatey'; ProviderName = 'chocolatey'}) } -ModuleName PSDepend
                Mock Install-Package {} -ModuleName PSDepend
                Mock Find-Package {} -ModuleName PSDepend
            }

            It 'Returns $true when it finds an existing module' {
                Mock Get-Package {
                    [pscustomobject]@{
                        Version = '1.1'
                    }
                } -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\package.sameversion.depend.psd1" |
                        Test-Dependency @Verbose -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $True
            }

            It 'Returns $true when it finds an existing latest module' {
                Mock Get-Package {
                    [pscustomobject]@{
                        Version = '1.1'
                    }
                } -ModuleName PSDepend
                Mock Find-Package {
                    [pscustomobject]@{
                        Version = '1.1'
                    }
                } -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\package.latestversion.depend.psd1" |
                        Test-Dependency @Verbose -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $True
            }

            It "Returns `$false when it doesn't find an existing module" {
                Mock Get-Package { $null } -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\package.sameversion.depend.psd1" |
                        Test-Dependency @Verbose -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $False
            }

            It "Returns `$false when it finds an existing module with a lower version" {
                Mock Get-Package {
                    [pscustomobject]@{
                        Version = '1.0'
                    }
                } -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\package.sameversion.depend.psd1" |
                        Test-Dependency @Verbose -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $False
            }

            It "Returns `$false when it finds an existing module with a lower version than latest" {
                Mock Get-Package {
                    [pscustomobject]@{
                        Version = '1.0'
                    }
                } -ModuleName PSDepend
                Mock Find-Package {
                    [pscustomobject]@{
                        Version = '1.1'
                    }
                } -ModuleName PSDepend
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\package.latestversion.depend.psd1" |
                        Test-Dependency @Verbose -Quiet )
                $Results.Count | Should -Be 1
                $Results[0] | Should -Be $False
            }
        }
    }

    Describe "Command Type PS$PSVersion" {
        BeforeAll {
            $script:SavePath = (New-Item 'TestDrive:/PSDependPesterTest' -ItemType Directory -Force).FullName
        }

        Context 'Invokes a command' {
            BeforeAll {
                $script:Dependencies = @(Get-Dependency @Verbose -Path "$TestDepends\command.depend.psd1")
            }

            It 'Parses the command dependency type' {
                $script:Dependencies.count | Should -Be 1
                $script:Dependencies[0].DependencyType | Should -Be 'Command'
            }

            It 'Invokes a command' {
                $Output = Invoke-PSDepend @Verbose -Path "$TestDepends\command.depend.psd1" -Force
                $Output | Should -Be 'hello world'
            }
        }
    }

    Describe "Npm Type PS$PSVersion" {
        BeforeAll {
            $script:SavePath = (New-Item 'TestDrive:/PSDependPesterTest' -ItemType Directory -Force).FullName
        }

        Context 'Installs Dependency' {
            BeforeAll {
                Mock Get-NodeModule { return $null } -ModuleName PSDepend
                Mock Install-NodeModule {} -ModuleName PSDepend
                Mock New-Item { return $true } -ModuleName PSDepend
                Mock Push-Location -ModuleName PSDepend
                Mock Pop-Location -ModuleName PSDepend

                $script:Dependencies = Get-Dependency @Verbose -Path "$TestDepends\npm.depend.psd1"
                $script:Results = Invoke-PSDepend @Verbose -Path "$TestDepends\npm.depend.psd1" -Force
            }

            It 'Parses the Npm dependency type' {
                $script:Dependencies.count | Should -Be 2
                ( $script:Dependencies | Where-Object { $_.DependencyType -eq 'Npm' } ).Count | Should -Be 2
                ( $script:Dependencies | Where-Object { $_.DependencyName -like 'gitbook-cli' }).Version | Should -Be '2.3.0'
                ( $script:Dependencies | Where-Object { $_.DependencyName -like 'gitbook-cli' }).Target | Should -Be 'Global'
                ( $script:Dependencies | Where-Object { $_.DependencyName -like 'gitbook-summary' }).Version | Should -BeNullOrEmpty
            }

            It 'Invokes the Npm dependency type' {
                Should -Invoke Install-NodeModule -Times 2 -Exactly -Scope Context -ModuleName PSDepend
            }
        }

        Context 'Tests Dependency' {
            BeforeAll {
                Mock Install-NodeModule {} -ModuleName PSDepend
                Mock New-Item { return $true } -ModuleName PSDepend
                Mock Push-Location -ModuleName PSDepend
                Mock Pop-Location -ModuleName PSDepend

                $script:Dependencies = Get-Dependency @Verbose -Path "$TestDepends\npm.depend.psd1"
            }

            It 'Returns $false if the module is not installed' {
                Mock Get-NodeModule { return $null } -ModuleName PSDepend
                Invoke-PSDepend @Verbose -Path "$TestDepends\npm.depend.psd1" -Test -Quiet | Should -Be $false
            }

            It 'Returns $true if the module is installed' {
                Mock Get-NodeModule { return [pscustomobject]@{
                        'gitbook-cli' = @{
                            version = '2.3.0'
                        }
                    } } -ParameterFilter { $Global -eq $true } -ModuleName PSDepend
                Mock Get-NodeModule { return [pscustomobject]@{
                        'gitbook-summary' = @{
                            version = '1.2.3'
                        }
                    } } -ModuleName PSDepend
                Invoke-PSDepend @Verbose -Path "$TestDepends\npm.depend.psd1" -Test -Quiet | Should -Be $true
            }
        }
    }

    Describe "DotnetSdk Type PS$PSVersion" {
        BeforeAll {
            $script:IsWindowsEnv = !$PSVersionTable.Platform -or $PSVersionTable.Platform -eq "Win32NT"
            $script:GlobalDotnetSdkLocation = if ($script:IsWindowsEnv) {
                "$env:LocalAppData\Microsoft\dotnet" 
            } else {
                "$env:HOME/.dotnet" 
            }
            $script:DotnetFile = if ($script:IsWindowsEnv) {
                "dotnet.exe" 
            } else {
                "dotnet" 
            }
            $script:SavePath = '.dotnet'
        }

        Context 'Installs Dependency' {
            BeforeAll {
                $script:Dependency = Get-Dependency @Verbose -Path "$TestDepends\dotnetsdk.complex.depend.psd1"
            }

            It 'Parses the DotnetSdk dependency type' {
                $script:Dependency | Should -Not -BeNullOrEmpty
                $script:Dependency.DependencyType | Should -Be 'DotnetSdk'
                $script:Dependency.Version | Should -Be '2.1.300'
                $script:Dependency.DependencyName | Should -Be 'release'
                $script:Dependency.Target | Should -Be $script:SavePath
            }

            It 'Installs the .NET Core SDK to the specified directory' {
                Mock Test-Dotnet { return $false } -ModuleName PSDepend

                Invoke-PSDepend @Verbose -Path "$TestDepends\dotnetsdk.complex.depend.psd1" -Force
                Test-Path $script:SavePath | Should -BeTrue
            }

            It 'Does nothing if the .NET Core SDK is found' {
                Mock Test-Dotnet { return $true } -ModuleName PSDepend
                Mock Install-Dotnet -ModuleName PSDepend

                Invoke-PSDepend @Verbose -Path "$TestDepends\dotnetsdk.complex.depend.psd1" -Force
                Should -Invoke Install-Dotnet -Times 0 -Exactly -ModuleName PSDepend
            }

            AfterAll {
                Remove-Item -Force -Recurse $script:SavePath -ErrorAction SilentlyContinue
            }
        }

        Context 'Tests Dependency' {
            BeforeAll {
                Mock Get-Command { return $false } -ParameterFilter { $Name -eq 'dotnet' } -ModuleName PSDepend
                Mock Test-Path { return $true } -ParameterFilter { $Path -eq (Join-Path $script:GlobalDotnetSdkLocation $script:DotnetFile) } -ModuleName PSDepend
                Mock Get-DotnetVersion { return '2.1.330-rc1' } -ModuleName PSDepend
            }

            It 'Can propertly compare semantic versions' {
                # '2.1.330-rc1' >= '2.1.330-preview1'
                # '2.1.330-rc1' >= '2.1.330-rc1'
                # '2.1.330-rc1' >= '1.0'
                Invoke-PSDepend @Verbose -Path "$TestDepends\dotnetsdk.semanticversion.depend.psd1" -Test -Quiet | Should -BeTrue
            }
        }

        Context 'Imports Dependency' {
            BeforeAll {
                Mock Get-Command { return $false } -ParameterFilter { $Name -eq 'dotnet' } -ModuleName PSDepend
                $script:originalPath = $env:PATH
            }

            AfterEach {
                $env:PATH = $script:originalPath
            }

            It 'Can add the Target of the .NET Core SDK to the PATH' {
                Mock Test-Dotnet { return $true } -ModuleName PSDepend
                Invoke-PSDepend @Verbose -Path "$TestDepends\dotnetsdk.complex.depend.psd1" -Force -Import -ErrorAction Stop

                ($env:PATH -split [IO.Path]::PathSeparator)[0] | Should -Be $script:SavePath
            }
            It 'Can add the global path of the .NET Core SDK to the PATH' {
                Mock Test-Dotnet { return $true } -ModuleName PSDepend
                Invoke-PSDepend @Verbose -Path "$TestDepends\dotnetsdk.simple.depend.psd1" -Force -Import -ErrorAction Stop

                ($env:PATH -split [IO.Path]::PathSeparator)[0] | Should -Be $script:GlobalDotnetSdkLocation
            }
            It 'Throws if the path cannot be found' {
                Mock Test-Dotnet { return $false } -ModuleName PSDepend
                { Invoke-PSDepend @Verbose -Path "$TestDepends\dotnetsdk.simple.depend.psd1" -Force -Import -ErrorAction Stop } |
                    Should -Throw -ExpectedMessage ".NET SDK cannot be located. Try installing using PSDepend."
            }
        }
    }

    Describe "Chocolatey Type PS$PSVersion" -Tag 'Chocolatey', 'WindowsOnly' -Skip:$nonWindows {
        BeforeAll {
            $script:SavePath = (New-Item 'TestDrive:/PSDependPesterTest' -ItemType Directory -Force).FullName

            # Simulate choco.exe being present so tests don't hit the install-chocolatey branch by default
            Mock Get-Command -ParameterFilter { $Name -eq 'choco.exe' } -MockWith { [pscustomobject]@{Name = 'choco.exe'} } -ModuleName PSDepend
            # Default catch-all for Invoke-ExternalCommand; individual tests register specific ParameterFilter mocks
            Mock Invoke-ExternalCommand -ModuleName PSDepend
        }

        Context 'Chocolatey is not installed' {

            It 'installs Chocolatey' {
                Mock Get-Command -ParameterFilter { $Name -eq 'choco.exe' } -MockWith { return $false } -ModuleName PSDepend
                Mock Invoke-WebRequest -ModuleName PSDepend

                # this will throw as the source is invalid - lets catch that
                { Invoke-PSDepend @Verbose -Path "$TestDepends\chocolatey.specificversionrequested.depend.psd1" -Force -ErrorAction Stop } | Should -Throw

                Should -Invoke Get-Command -Times 1 -Exactly -ModuleName PSDepend
                Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ModuleName PSDepend
            }
        }

        Context 'Source does not exist' {

            It 'Does not throw if the Source cannot be found' {
                { Invoke-PSDepend -Path "$TestDepends\chocolatey.dummysource.depend.psd1" -Force -ErrorAction Stop } | Should -Not -Throw
            }
        }

        Context 'Package version installed is what is requested' {

            It 'skips installing the package' {
                Mock Invoke-ExternalCommand { "7zip|1.0" } -ParameterFilter { $Arguments -contains '--local-only' } -ModuleName PSDepend

                Invoke-PSDepend @Verbose -Path "$TestDepends\chocolatey.specificversionrequested.depend.psd1" -Force -ErrorAction Stop

                Should -Invoke Invoke-ExternalCommand -ParameterFilter { $Arguments -contains '--local-only' } -Times 1 -Exactly -ModuleName PSDepend
                Should -Invoke Invoke-ExternalCommand -ParameterFilter { $Arguments[0] -eq 'list' -and $Arguments -notcontains '--local-only' } -Times 0 -Exactly -ModuleName PSDepend
                Should -Invoke Invoke-ExternalCommand -ParameterFilter { $Arguments[0] -eq 'upgrade' } -Times 0 -Exactly -ModuleName PSDepend
            }
        }

        Context 'Package version installed is latest' {

            It 'skips installing the package' {
                Mock Invoke-ExternalCommand { "7zip|2.0" } -ParameterFilter { $Arguments -contains '--local-only' } -ModuleName PSDepend
                Mock Invoke-ExternalCommand { "7zip|2.0" } -ParameterFilter { $Arguments[0] -eq 'list' -and $Arguments -notcontains '--local-only' } -ModuleName PSDepend

                Invoke-PSDepend @Verbose -Path "$TestDepends\chocolatey.latestversionrequested.depend.psd1" -Force -ErrorAction Stop

                Should -Invoke Invoke-ExternalCommand -ParameterFilter { $Arguments -contains '--local-only' } -Times 1 -Exactly -ModuleName PSDepend
                Should -Invoke Invoke-ExternalCommand -ParameterFilter { $Arguments[0] -eq 'list' -and $Arguments -notcontains '--local-only' } -Times 1 -Exactly -ModuleName PSDepend
                Should -Invoke Invoke-ExternalCommand -ParameterFilter { $Arguments[0] -eq 'upgrade' } -Times 0 -Exactly -ModuleName PSDepend
            }
        }

        Context 'Package requested is latest and version installed is newer than available in source' {

            It 'skips installing the package' {
                Mock Invoke-ExternalCommand { "7zip|2.0" } -ParameterFilter { $Arguments -contains '--local-only' } -ModuleName PSDepend
                Mock Invoke-ExternalCommand { "7zip|1.0" } -ParameterFilter { $Arguments[0] -eq 'list' -and $Arguments -notcontains '--local-only' } -ModuleName PSDepend

                Invoke-PSDepend @Verbose -Path "$TestDepends\chocolatey.latestversionrequested.depend.psd1" -Force -ErrorAction Stop

                Should -Invoke Invoke-ExternalCommand -ParameterFilter { $Arguments -contains '--local-only' } -Times 1 -Exactly -ModuleName PSDepend
                Should -Invoke Invoke-ExternalCommand -ParameterFilter { $Arguments[0] -eq 'list' -and $Arguments -notcontains '--local-only' } -Times 1 -Exactly -ModuleName PSDepend
                Should -Invoke Invoke-ExternalCommand -ParameterFilter { $Arguments[0] -eq 'upgrade' } -Times 0 -Exactly -ModuleName PSDepend
            }
        }

        Context 'Package requested is latest and version installed is older than available in source' {

            It 'installs the package' {
                Mock Invoke-ExternalCommand { "7zip|1.0" } -ParameterFilter { $Arguments -contains '--local-only' } -ModuleName PSDepend
                Mock Invoke-ExternalCommand { "7zip|2.0" } -ParameterFilter { $Arguments[0] -eq 'list' -and $Arguments -notcontains '--local-only' } -ModuleName PSDepend

                Invoke-PSDepend @Verbose -Path "$TestDepends\chocolatey.latestversionrequested.depend.psd1" -Force -ErrorAction Stop

                Should -Invoke Invoke-ExternalCommand -ParameterFilter { $Arguments -contains '--local-only' } -Times 1 -Exactly -ModuleName PSDepend
                Should -Invoke Invoke-ExternalCommand -ParameterFilter { $Arguments[0] -eq 'list' -and $Arguments -notcontains '--local-only' } -Times 1 -Exactly -ModuleName PSDepend
                Should -Invoke Invoke-ExternalCommand -ParameterFilter { $Arguments[0] -eq 'upgrade' } -Times 1 -Exactly -ModuleName PSDepend
            }
        }
    }
}
