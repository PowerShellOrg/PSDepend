function Test-VersionEquality {
    <#
    .SYNOPSIS
    Compare two versions by casting and comparing individual components.

    .DESCRIPTION
    Compare two version strings by attempting to parse them as System.Version
    and System.Management.Automation.SemanticVersion, and comparing their
    components. If parsing fails, fall back to string comparison.

    .PARAMETER ReferenceVersion
    The reference version string to compare against.

    .PARAMETER DifferenceVersion
    The version string to compare with the reference version.

    .EXAMPLE
    Test-VersionEquality -ReferenceVersion '1.2.3' -DifferenceVersion '1.2.3'

    Returns true for identical three-part versions.

    .EXAMPLE
    Test-VersionEquality -ReferenceVersion '1.2.0' -DifferenceVersion '1.2'

    Returns true when both omit build (treated as 0).

    .EXAMPLE
    Test-VersionEquality -ReferenceVersion '1.2.3' -DifferenceVersion '1.2.4'

    Returns false when build differs.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$ReferenceVersion,
        [string]$DifferenceVersion
    )

    # First, check if either version string is null or empty. If so, they can't
    # be equal.
    if (
        [string]::IsNullOrEmpty($ReferenceVersion) -or
        [string]::IsNullOrEmpty($DifferenceVersion)
    ) {
        return $false
    }

    # Parsing requires existing references to exist, so we create them.
    [System.Version]$parsedRef = $null
    [System.Version]$parsedDiff = $null

    # Check if we can parse both versions as System.Version. If we can, we
    # compare them using individual components.
    # Because System.Version treats missing components as -1, we use Math.Max to
    # treat them as 0 for comparison purposes (e.g. 1.2 is treated as 1.2.0.0).
    if ([System.Version]::TryParse($ReferenceVersion, [ref]$parsedRef) -and
        [System.Version]::TryParse($DifferenceVersion, [ref]$parsedDiff)
    ) {
        return (
            $parsedRef.Major -eq $parsedDiff.Major -and
            $parsedRef.Minor -eq $parsedDiff.Minor -and
            [Math]::Max($parsedRef.Build, 0) -eq [Math]::Max($parsedDiff.Build, 0) -and
            [Math]::Max($parsedRef.Revision, 0) -eq [Math]::Max($parsedDiff.Revision, 0)
        )
    }

    # If they can't be parsed as System.Version, we attempt to parse them as
    # SemanticVersion, which can handle prerelease and build metadata.
    [System.Management.Automation.SemanticVersion]$parsedRefSemVer = $null
    [System.Management.Automation.SemanticVersion]$parsedDiffSemVer = $null

    if (
        [System.Management.Automation.SemanticVersion]::TryParse(
            $ReferenceVersion, [ref]$parsedRefSemVer
        ) -and
        [System.Management.Automation.SemanticVersion]::TryParse(
            $DifferenceVersion, [ref]$parsedDiffSemVer
        )
    ) {
        return $parsedRefSemVer -eq $parsedDiffSemVer
    }

    # TODO: Investigate if we want to add additional parsing logic here for
    # other version formats (e.g. date or commit based versions)

    return $ReferenceVersion -eq $DifferenceVersion
}
