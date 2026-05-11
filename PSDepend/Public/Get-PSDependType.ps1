Function Get-PSDependType {
    <#
    .SYNOPSIS
        Get dependency types and related information

    .DESCRIPTION
        Get dependency types and related information

        Checks PSDependMap.psd1 for dependency types,
        verifies dependency scripts exist,
        gets help content for dependency scripts,
        returns various info on each dependency type

    .PARAMETER Path
        Path to PSDependMap.psd1 defining dependency types

        Defaults to PSDependMap.psd1 in the module root

    .PARAMETER DependencyType
        Optionally limited to this DependencyType

        Accepts wildcards

    .PARAMETER ShowHelp
        Show help content for specified dependency types

    .PARAMETER SkipHelp
        Skip retreieving help. Mainly for internl use when it is not required

    .EXAMPLE
        Get-PSDependType -DependencyType PSGalleryModule -ShowHelp

        Show help for the PSGalleryModule dependency type.

    .EXAMPLE
        Get-PSDependType

        # List dependency types defined in PSDependMap.psd1 in the root of your PSDepend module folder

    .EXAMPLE
        Get-PSDependType -Path \\Path\To\Central.DependencyMap.psd1

        # List dependency types defined in a centralized dependency map

    .LINK
        https://github.com/PowerShellOrg/PSDepend
    #>
    [cmdletbinding()]
    param(
        [string]$DependencyType = '*',
        [validatescript({Test-Path $_ -PathType Leaf -ErrorAction Stop})]
        [string]$Path = $(Join-Path $ModuleRoot PSDependMap.psd1),
        [switch]$ShowHelp,
        [switch]$SkipHelp
    )

    # Read the file
    $Base = Split-Path $Path -Parent
    $File = Split-Path $Path -Leaf
    $DependencyDefinitions = Import-LocalizedData -BaseDirectory $Base -FileName $File
    $KeysToQuery = $DependencyDefinitions.Keys |
        Where-Object {$_ -like $DependencyType} |
        Sort-Object
    foreach($Type in $KeysToQuery)
    {
        #Determine the path to this script. Skip task dependencies...
        $Script =  $DependencyDefinitions.$Type.Script
        if($Script -ne '.')
        {
            if(Test-Path $Script)
            {
                $ScriptPath = $Script
            }
            else
            {
                # account for missing ps1
                $ScriptPath = Join-Path $ModuleRoot "PSDependScripts\$($Script -replace ".ps1$").ps1"
            }

            If (-not $SkipHelp) {
                Try
                {
                    $ScriptHelp = Get-Help $ScriptPath -Full -ErrorAction Stop
                }
                Catch
                {
                    $ScriptHelp = "Error retrieving help: $_"
                }
            }
        }
        if($ShowHelp)
        {
            $ScriptHelp
        }
        else
        {
            $Support = @($DependencyDefinitions.$Type.Supports)
            [pscustomobject]@{
                DependencyType = $Type
                Supports = $Support
                Supported = Test-PlatformSupport -Type $Type -Support $Support
                Description = $DependencyDefinitions.$Type.Description
                DependencyScript = $ScriptPath
                HelpContent = $ScriptHelp
            }
        }
    }
}
