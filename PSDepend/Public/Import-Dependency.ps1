Function Import-Dependency {
    <#
    .SYNOPSIS
        Import a specific dependency

    .DESCRIPTION
        Import a specific dependency, if that dependency supports it.

        Takes output from Get-Dependency

          * Runs dependency scripts depending on each dependencies type.
          * Imports items if supported

        See Get-Help about_PSDepend for more information.

    .PARAMETER Dependency
        Dependency object from Get-Dependency.

    .PARAMETER PSDependTypePath
        Specify a PSDependMap.psd1 file that maps DependencyTypes to their scripts.

        This defaults to the PSDependMap.psd1 in the PSDepend module folder

    .PARAMETER Tags
        Only test dependencies that are tagged with all of the specified Tags (-and, not -or)

    .EXAMPLE
        Get-Dependency -Path C:\requirements.psd1 | Import-Dependency

        Get dependencies from C:\requirements.psd1 and import them

    .LINK
        https://github.com/PowerShellOrg/PSDepend
    #>
    [cmdletbinding()]
    Param(
        [parameter( ValueFromPipeline = $True,
                    ParameterSetName='Map',
                    Mandatory = $True)]
        [PSTypeName('PSDepend.Dependency')]
        [psobject[]]$Dependency,

        [validatescript({Test-Path -Path $_ -PathType Leaf -ErrorAction Stop})]
        [string]$PSDependTypePath = $(Join-Path $ModuleRoot PSDependMap.psd1),

        [string[]]$Tags
    )
    Process
    {
        Invoke-DependencyScript @PSBoundParameters -PSDependAction Import
    }
}
