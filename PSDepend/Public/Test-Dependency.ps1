function Test-Dependency {
    <#
    .SYNOPSIS
        Test a specific dependency

    .DESCRIPTION
        Test a specific dependency.  Validates whether a dependency exists

        Takes output from Get-Dependency

          * Runs dependency scripts depending on each dependencies type.
          * Appends a 'DependencyExists' property indicating whether the dependency exists; alternatively
          * Returns $True or $False if the -Quiet switch is used

        See Get-Help about_PSDepend for more information.

    .PARAMETER Dependency
        Dependency object from Get-Dependency.

    .PARAMETER PSDependTypePath
        Specify a PSDependMap.psd1 file that maps DependencyTypes to their scripts.

        This defaults to the PSDependMap.psd1 in the PSDepend module folder

    .PARAMETER Tags
        Only test dependencies that are tagged with all of the specified Tags (-and, not -or)

    .PARAMETER Quiet
        Return $true or $false based on whether a dependency exists

    .EXAMPLE
        Get-Dependency -Path C:\requirements.psd1 | Test-Dependency

        Get dependencies from C:\requirements.psd1 and test whether they exist

    .LINK
        https://github.com/PowerShellOrg/PSDepend
    #>
    [cmdletbinding()]
    param(
        [parameter( ValueFromPipeline = $True,
            ParameterSetName='Map',
            Mandatory = $True)]
        [PSTypeName('PSDepend.Dependency')]
        [psobject[]]$Dependency,

        [validatescript({ Test-Path -Path $_ -PathType Leaf -ErrorAction Stop })]
        [string]$PSDependTypePath = $(Join-Path $ModuleRoot PSDependMap.psd1),

        [string[]]$Tags,

        [switch]$Quiet
    )
    process {
        Invoke-DependencyScript @PSBoundParameters -PSDependAction Test
    }
}
