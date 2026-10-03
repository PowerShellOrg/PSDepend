function Test-PSDependExactVersion {
    <#
    .SYNOPSIS
    Test whether a value is a concrete package version.

    .DESCRIPTION
    Accepts semantic versions, including prerelease labels, and four-part
    System.Version values. Rejects ranges, tags, URLs and package-manager specs.

    .PARAMETER Version
    Version text to validate.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [string]$Version
    )

    if ([string]::IsNullOrWhiteSpace($Version)) { return $false }
    [System.Management.Automation.SemanticVersion]$semanticVersion = $null
    [System.Version]$systemVersion = $null
    [System.Management.Automation.SemanticVersion]::TryParse($Version, [ref]$semanticVersion) -or
        [System.Version]::TryParse($Version, [ref]$systemVersion)
}
