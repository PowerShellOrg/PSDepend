Function Install-Dependency {
    <#
    .SYNOPSIS
        Install a specific dependency

    .DESCRIPTION
        Install a specific dependency.  Typically you would use Invoke-PSDepend rather than this.

        Takes output from Get-Dependency

          * Runs dependency scripts depending on each dependencies type.
          * If a dependency is not found, we continue processing other dependencies.

        See Get-Help about_PSDepend for more information.

    .PARAMETER Dependency
        Dependency object from Get-Dependency.

    .PARAMETER PSDependTypePath
        Specify a PSDependMap.psd1 file that maps DependencyTypes to their scripts.

        This defaults to the PSDependMap.psd1 in the PSDepend module folder

    .PARAMETER Tags
        Only invoke dependencies that are tagged with all of the specified Tags (-and, not -or)

    .PARAMETER Force
        Force installation, skipping prompts and confirmation

    .EXAMPLE
        Get-Dependency -Path C:\requirements.psd1 | Install-Dependency

        Get dependencies from C:\requirements.psd1 and install them

    .LINK
        https://github.com/PowerShellOrg/PSDepend
    #>
    [cmdletbinding( SupportsShouldProcess = $True,
                    ConfirmImpact='High' )]
    Param(
        [parameter( ValueFromPipeline = $True,
                    Mandatory = $True)]
        [PSTypeName('PSDepend.Dependency')]
        [psobject[]]$Dependency,

        [validatescript({Test-Path -Path $_ -PathType Leaf -ErrorAction Stop})]
        [string]$PSDependTypePath = $(Join-Path $ModuleRoot PSDependMap.psd1),

        [string[]]$Tags,

        [switch]$Force
    )
    Process
    {
        $InvokeParams = @{} + $PSBoundParameters
        $null = $InvokeParams.Remove('Force')
        Invoke-DependencyScript @InvokeParams -PSDependAction Install
    }
}
