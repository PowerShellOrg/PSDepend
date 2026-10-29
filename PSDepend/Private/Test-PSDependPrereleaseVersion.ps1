function Test-PSDependPrereleaseVersion {
    <#
    .SYNOPSIS
    Heuristically test whether an exact version string looks like a prerelease.

    .DESCRIPTION
    Returns $true when Version has a dash-delimited suffix after 1-4 numeric
    dot-separated components (e.g. '0.7.0-beta1', '2.5.0-alpha', or with SemVer
    2.0 build metadata like '1.0.0-beta+build.5'). Used to warn callers who
    pinned a prerelease version but didn't pass AllowPrerelease.

    This is a heuristic, not a strict validity check: it is intentionally
    looser than SemVer (it accepts 4 numeric components, and doesn't enforce
    per-identifier SemVer grammar such as "no leading zero"), because a false
    positive here only produces an extra warning, while a false negative
    silently lets Install-Module fail to find the module. See
    docs/PSDependScripts-PrereleaseVersionDetection.md for the full version
    matrix this was validated against.

    Deliberately does not use [System.Management.Automation.SemanticVersion]:
    that type isn't available in the inbox Windows PowerShell 5.1 assembly
    (confirmed via PSScriptAnalyzer's UseCompatibleTypes rule, which uses this
    exact type as its worked example of a type missing from the 5.1 profile),
    and PSDepend's manifest declares PowerShellVersion = '5.1'. A regex has no
    such runtime-availability risk.

    .PARAMETER Version
    An exact (non-range) version string to test.

    .EXAMPLE
    Test-PSDependPrereleaseVersion -Version '0.7.0-beta1'

    Returns $true.

    .EXAMPLE
    Test-PSDependPrereleaseVersion -Version '1.2.3'

    Returns $false - no prerelease suffix.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [AllowNull()]
        [string]$Version
    )

    if ([string]::IsNullOrWhiteSpace($Version)) { return $false }

    $Version -match '^\d+(\.\d+){1,3}-[0-9A-Za-z][0-9A-Za-z.+-]*$'
}
