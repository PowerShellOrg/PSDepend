# Taken with love from @juneb_get_help (https://raw.githubusercontent.com/juneb/PesterTDD/master/Module.Help.Tests.ps1)

BeforeDiscovery {
    if ($null -eq $env:BHPSModuleManifest) {
        & "$PSScriptRoot/../Build.ps1" -Task Init
    }
    function global:FilterOutCommonParams {
        param ($Params)
        $commonParameters = [System.Management.Automation.PSCmdlet]::CommonParameters +
        [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
        $params | Where-Object { $_.Name -notin $commonParameters } | Sort-Object -Property Name -Unique
    }

    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Output'
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputModVerManifest = Join-Path -Path $outputModVerDir -ChildPath "$($env:BHProjectName).psd1"

    # Get module commands
    # Remove all versions of the module from the session. Pester can't handle multiple versions.
    Get-Module $env:BHProjectName | Remove-Module -Force -ErrorAction Ignore
    Import-Module -Name $outputModVerManifest -Verbose:$false -ErrorAction Stop
    $params = @{
        Module = (Get-Module $env:BHProjectName)
        CommandType = [System.Management.Automation.CommandTypes[]]'Cmdlet, Function' # Not alias
    }
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        $params.CommandType[0] += 'Workflow'
    }
    $commands = Get-Command @params

    ## When testing help, remember that help is cached at the beginning of each session.
    ## To test, restart session.
}

Describe "Test help for <_.Name>" -ForEach $commands {

    BeforeDiscovery {
        # Get command help, parameters, and links
        $command = $_
        $commandHelp = Get-Help $command.Name -ErrorAction SilentlyContinue
        $commandParameters = global:FilterOutCommonParams -Params $command.ParameterSets.Parameters
        $commandParameterNames = $commandParameters.Name
        $helpLinks = @($commandHelp.relatedLinks.navigationLink.uri | Where-Object { $_ })
        $helpParameters = global:FilterOutCommonParams -Params $commandHelp.Parameters.Parameter
        $helpParameterNames = $helpParameters.Name
    }

    BeforeAll {
        # These vars are needed in both discovery and test phases so we need to duplicate them here
        $script:command = $_
        $script:commandName = $_.Name
        $script:commandHelp = Get-Help $script:command.Name -ErrorAction SilentlyContinue
        $script:commandParameters = global:FilterOutCommonParams -Params $script:command.ParameterSets.Parameters
        $script:commandParameterNames = $script:commandParameters.Name
        $script:helpParameters = global:FilterOutCommonParams -Params $script:commandHelp.Parameters.Parameter
        $script:helpParameterNames = $script:helpParameters.Name
    }

    # If help is not found, synopsis in auto-generated help is the syntax diagram
    It 'Help is not auto-generated' {
        $script:commandHelp.Synopsis | Should -Not -BeLike '*`[`<CommonParameters`>`]*'
    }

    # Should be a description for every function
    It "Has description" {
        $script:commandHelp.Description | Should -Not -BeNullOrEmpty
    }

    # Should be at least one example
    It "Has example code" {
        ($script:commandHelp.Examples.Example | Select-Object -First 1).Code | Should -Not -BeNullOrEmpty
    }

    # Should be at least one example description
    It "Has example help" {
        ($script:commandHelp.Examples.Example.Remarks | Select-Object -First 1).Text | Should -Not -BeNullOrEmpty
    }

    It "Help link <_> is valid" -Tag 'Acceptance' -ForEach $helpLinks {
        (Invoke-WebRequest -Uri $_ -UseBasicParsing -TimeoutSec 10).StatusCode | Should -Be '200'
    }

    Context "Parameter <_.Name>" -ForEach $commandParameters {

        BeforeAll {
            $script:parameter = $_
            $script:parameterName = $script:parameter.Name
            $script:parameterHelp = $script:commandHelp.parameters.parameter | Where-Object Name -EQ $script:parameterName
            $script:parameterHelpType = if ($script:parameterHelp.ParameterValue) {
                $script:parameterHelp.ParameterValue.Trim()
            }
        }

        # Should be a description for every parameter
        It "Has description" {
            $script:parameterHelp.Description.Text | Should -Not -BeNullOrEmpty
        }

        # Required value in Help should match IsMandatory property of parameter
        It "Has correct [mandatory] value" {
            $codeMandatory = $_.IsMandatory.toString()
            $script:parameterHelp.Required | Should -Be $codeMandatory
        }

        # Parameter type in help should match code
        It "Has correct parameter type" {
            $script:parameterHelpType | Should -Be $script:parameter.ParameterType.Name
        }
    }

    Context "Test <_> help parameter help for <commandName>" -ForEach $helpParameterNames {

        # Shouldn't find extra parameters in help.
        It "finds help parameter in code: <_>" {
            $_ -in $script:commandParameterNames | Should -Be $true
        }
    }
}
