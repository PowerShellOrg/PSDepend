function Get-PSDependScript {
    <#
    .SYNOPSIS
        Get dependency types and associated scripts

    .DESCRIPTION
        Get dependency types and associated scripts

        Checks PSDependMap.psd1,
        verifies dependency scripts exist,
        returns a hashtable of these.

    .PARAMETER Path
        Path to PSDependMap.psd1 defining dependency types

        Defaults to PSDependMap.psd1 in the module root

    .EXAMPLE
        Get-PSDependScript

        # List PSDepend scripts available in the PSDependMap.psd1 in the PSDepend module root

    .EXAMPLE
        Get-PSDependScript -Path \\Path\To\Central.DependencyMap.psd1

        # List dependency types defined in a centralized dependency map

    .LINK
        https://github.com/PowerShellOrg/PSDepend
    #>
    [cmdletbinding()]
    param(
        [validatescript({ Test-Path $_ -PathType Leaf -ErrorAction Stop })]
        [string]$Path = $(Join-Path $ModuleRoot PSDependMap.psd1)
    )

    # Read the file
    $Base = Split-Path $Path -Parent
    $File = Split-Path $Path -Leaf
    $DependencyDefinitions = Import-LocalizedData -BaseDirectory $Base -FileName $File

    $DependHash = @{}
    foreach($DependencyType in $DependencyDefinitions.Keys) {
        #Determine the path to this script
        $Script =  $DependencyDefinitions.$DependencyType.Script
        if(Test-Path $Script -ErrorAction SilentlyContinue) {
            $ScriptPath = $Script
        } else {
            # account for missing ps1
            $ScriptPath = Join-Path $ModuleRoot "PSDependScripts\$($Script -replace ".ps1$").ps1"
        }

        if(Test-Path $ScriptPath) {
            $DependHash.$DependencyType = $ScriptPath
        } else {
            Write-Error "Could not find path '$ScriptPath' for dependency $DependencyType. Origin: $($DependencyDefinitions.$DependencyType.Script)"
        }
    }

    $DependHash
}



