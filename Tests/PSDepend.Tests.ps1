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

    $PSVersion = $PSVersionTable.PSVersion.Major  # discovery-scope for Describe names
}


BeforeAll {
    $script:TestDepends = Join-Path $ENV:BHProjectPath Tests\DependFiles
    $script:Verbose = @{}
    if($ENV:BHBranchName -notlike "master" -or $env:BHCommitMessage -match "!verbose") {
        $script:Verbose.add("Verbose",$True)
    }
}

Describe "$ENV:BHProjectName PS$PSVersion" -Tag 'Unit' {
    Context 'Strict mode' {
        BeforeAll { Set-StrictMode -Version latest }
        AfterAll  { Set-StrictMode -Off }

        It 'Should load' {
            $Module = Get-Module $ENV:BHProjectName
            $Module.Name | Should -Be $ENV:BHProjectName
            $Module.ExportedFunctions.Keys -contains 'Get-Dependency' | Should -Be $True
        }
    }
}

Describe "Get-Dependency PS$PSVersion" -Tag 'Unit' {
    Context 'Strict mode' {
        BeforeAll { Set-StrictMode -Version latest }
        AfterAll  { Set-StrictMode -Off }

        It 'Should read ModuleName=Version syntax' {
            $Dependencies = Get-Dependency -Path $TestDepends\simple.depend.psd1
            $Dependencies.Count | Should -Be 4
            @( $Dependencies.DependencyType -like 'PSGalleryModule' ).count | Should -Be 4
            @( $Dependencies | Where-Object { $_.Name -like $_.DependencyName } ).count | Should -Be 4
        }

        It 'Should read DependencyType::DependencyName=Version syntax' {
            $Dependencies = Get-Dependency -Path $TestDepends\simple.helpers.depend.psd1
            $Dependencies.Count | Should -Be 2
            @( $Dependencies.DependencyType -like 'PSGalleryModule' ).count | Should -Be 1
            @( $Dependencies.DependencyType -like 'GitHub' ).count | Should -Be 1
            @( $Dependencies | Where-Object { $_.Name -like $_.DependencyName } ).count | Should -Be 2
        }

        It 'Should read each property correctly' {
            $Dependencies = Get-Dependency -Path $TestDepends\allprops.depend.psd1
            @( $Dependencies ).count | Should -Be 1
            $Dependencies.DependencyName | Should -Be 'DependencyName'
            $Dependencies.Name | Should -Be 'Name'
            $Dependencies.Version | Should -Be 'Version'
            $Dependencies.DependencyType | Should -Be 'noop'
            $Dependencies.Parameters.ContainsKey('Random') | Should -Be $True
            $Dependencies.Parameters['Random'] | Should -Be 'Value'
            $Dependencies.Source | Should -Be 'Source'
            $Dependencies.Target | Should -Be 'Target'
            $Dependencies.AddToPath | Should -Be $True
            $Dependencies.Tags.Count | Should -Be 2
            $Dependencies.Tags -contains 'tags' | Should -Be $True
            $Dependencies.DependsOn | Should -Be 'DependsOn'
            $Dependencies.PreScripts | Should -Be 'C:\PreScripts.ps1'
            $Dependencies.PostScripts | Should -Be 'C:\PostScripts.ps1'
            $Dependencies.Raw.ContainsKey('ExtendedSchema') | Should -Be $True
            $Dependencies.Raw.ExtendedSchema['IsTotally'] | Should -Be 'Captured'
        }

        It 'Should handle DependsOn' {
            $Dependencies = Get-Dependency -Path $TestDepends\dependson.depend.psd1
            @( $Dependencies ).count | Should -Be 3
            $Dependencies[0].DependencyName | Should -Be 'One'
            $Dependencies[1].DependencyName | Should -Be 'Two'
            $Dependencies[2].DependencyName | Should -Be 'THree'
        }

        It 'Should inject variables' {
            $Dependencies = Get-Dependency -Path $TestDepends\inject.variables.depend.psd1
            $DependencyFolder = Split-Path $Dependencies.DependencyFile -Parent
            $Dependencies.Source | Should -Be "PWD=$($PWD.Path)"
            $Dependencies.Target | Should -Be "$($PWD.Path)\Dependencies;$DependencyFolder"
        }

        It 'Should not mangle dependencies if multiple PSGallery modules specified' {
            $Dependencies = Get-Dependency -Path $TestDepends\multiplepsgallerymodule.depend.psd1
            $Dependencies.Count | Should -Be 3
            $Dependencies[0].Version | Should -BeNullOrEmpty
            $Dependencies[1].Version | Should -BeNullOrEmpty
            $Dependencies[2].Version | Should -BeNullOrEmpty
            @($Dependencies[0].Tags) -contains 'prd' | Should -Be $True
            @($Dependencies[1].Tags) -contains 'prd' | Should -Be $True
            @($Dependencies[2].Tags) -contains 'prd' | Should -Be $True
        }
    }

    Context 'Error and edge cases' {
        BeforeAll { Set-StrictMode -Version latest }
        AfterAll  { Set-StrictMode -Off }

        It 'Filters results to matching tags when -Tags is specified' {
            $Dependencies = Get-Dependency -Path $TestDepends\allprops.depend.psd1 -Tags 'tags'
            $Dependencies | Should -Not -BeNullOrEmpty
            $Dependencies.DependencyName | Should -Be 'DependencyName'
        }

        It 'Returns nothing when -Tags matches no dependency' {
            $Dependencies = Get-Dependency -Path $TestDepends\allprops.depend.psd1 -Tags 'nonexistenttag' -WarningAction SilentlyContinue
            $Dependencies | Should -BeNullOrEmpty
        }

        It 'Parses -InputObject hashtable as PSGalleryModule by default' {
            $Dependencies = Get-Dependency -InputObject @{ Pester = 'latest' }
            $Dependencies.DependencyName | Should -Be 'Pester'
            $Dependencies.DependencyType | Should -Be 'PSGalleryModule'
            $Dependencies.Version | Should -Be 'latest'
        }
    }
}

Describe "Get-PSDependType PS$PSVersion" -Tag 'Unit' {
    Context 'Strict mode' {
        BeforeAll { Set-StrictMode -Version latest }
        AfterAll  { Set-StrictMode -Off }

        It 'Returns objects for all types in the default map' {
            $Types = Get-PSDependType -SkipHelp
            $Types | Should -Not -BeNullOrEmpty
            $Types[0].DependencyType | Should -Not -BeNullOrEmpty
        }

        It 'Returns a bool Supported flag for every type' {
            $Types = Get-PSDependType -SkipHelp
            foreach ($Type in $Types) {
                $Type.Supported | Should -BeOfType [bool]
            }
        }

        It 'Filters by DependencyType wildcard' {
            $Types = Get-PSDependType -DependencyType 'PSGallery*' -SkipHelp
            $Types | Should -Not -BeNullOrEmpty
            $Types | ForEach-Object { $_.DependencyType | Should -BeLike 'PSGallery*' }
        }

        It 'Throws on an invalid Path' {
            { Get-PSDependType -Path 'C:\DoesNotExist\map.psd1' -SkipHelp } | Should -Throw
        }
    }
}

Describe "Get-PSDependScript PS$PSVersion" -Tag 'Unit' {
    Context 'Strict mode' {
        BeforeAll { Set-StrictMode -Version latest }
        AfterAll  { Set-StrictMode -Off }

        It 'Returns a hashtable keyed by dependency type name' {
            $Scripts = Get-PSDependScript
            $Scripts | Should -BeOfType [hashtable]
            $Scripts.ContainsKey('PSGalleryModule') | Should -Be $True
        }

        It 'Maps each type to an existing .ps1 file' {
            $Scripts = Get-PSDependScript
            foreach ($Key in $Scripts.Keys) {
                Test-Path $Scripts[$Key] | Should -Be $True -Because "$Key must point to an existing script"
            }
        }

        It 'Throws on an invalid Path' {
            { Get-PSDependScript -Path 'C:\DoesNotExist\map.psd1' } | Should -Throw
        }
    }
}

Describe "Install-Dependency PS$PSVersion" -Tag 'Unit' {
    Context 'PSGalleryModule install' {
        BeforeAll {
            Set-StrictMode -Version latest
            Mock Install-Module {} -ModuleName PSDepend
        }
        AfterAll { Set-StrictMode -Off }

        It 'Calls Install-Module when given a PSGalleryModule dependency via pipeline' {
            Get-Dependency -Path $TestDepends\psgallerymodule.depend.psd1 |
                Install-Dependency -Force
            Should -Invoke Install-Module -Times 1 -Exactly -ModuleName PSDepend
        }
    }
}

Describe "Invoke-DependencyScript PS$PSVersion" -Tag 'Unit' {
    Context 'Command type' {
        BeforeAll { Set-StrictMode -Version latest }
        AfterAll  { Set-StrictMode -Off }

        It 'Returns the script output for a Command dependency' {
            $Dep = Get-Dependency -Path $TestDepends\command.depend.psd1 | Select-Object -First 1
            $Dep | Invoke-DependencyScript -PSDependAction Install | Should -Be 'hello world'
        }

        It 'Does not throw when PSDependAction is not valid for the dependency type' {
            $Dep = Get-Dependency -Path $TestDepends\psgallerymodule.depend.psd1 | Select-Object -First 1
            { $Dep | Invoke-DependencyScript -PSDependAction 'NonExistentAction' -WarningAction SilentlyContinue } |
                Should -Not -Throw
        }
    }

    Context 'Test action' {
        BeforeAll {
            Set-StrictMode -Version latest
            Mock Get-Module { [pscustomobject]@{ Version = '1.2.5' } } -ModuleName PSDepend
        }
        AfterAll { Set-StrictMode -Off }

        It 'Returns $true when the module is installed at the required version with -Quiet' {
            $Dep = Get-Dependency -Path $TestDepends\psgallerymodule.sameversion.depend.psd1
            $Dep | Invoke-DependencyScript -PSDependAction Test -Quiet | Should -Be $True
        }
    }
}