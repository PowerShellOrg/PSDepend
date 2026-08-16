function Resolve-VersionInRange {
    <#
    .SYNOPSIS
    Return the highest candidate version that satisfies a version range.

    .DESCRIPTION
    Gallery installers that cannot express a NuGet range natively (Install-Module,
    nuget.exe) need a single concrete version. This selects the highest of the
    supplied candidate versions that satisfies the requested range (exact or
    range), using the shared Test-VersionInRange predicate and Compare-Version
    ordering primitive so every installer resolves a range identically.

    Returns the winning version string, or $null when no candidate satisfies the
    range.

    .PARAMETER Candidate
    The available version strings to choose from.

    .PARAMETER Required
    The requested version string (exact or NuGet range).

    .EXAMPLE
    Resolve-VersionInRange -Candidate '1.9.0', '2.5.0', '3.0.0' -Required '[2.0.0,3.0.0)'

    Returns '2.5.0' - the highest candidate inside the half-open range.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string[]]$Candidate,
        [string]$Required
    )

    $resolved = $null
    foreach ($version in $Candidate) {
        if ((Test-VersionInRange -Version $version -Required $Required) -and
            ($null -eq $resolved -or (Compare-Version -ReferenceVersion $version -DifferenceVersion $resolved) -gt 0)) {
            $resolved = $version
        }
    }
    $resolved
}
