function Get-PSDependRequestedVersion {
    <#
    .SYNOPSIS
    Normalize an omitted Dependency Version to latest.

    .PARAMETER Version
    Declared Dependency Version.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param($Version)

    if ([string]::IsNullOrEmpty($Version)) { 'latest' } else { [string]$Version }
}
