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

    # Equality is the zero case of the shared ordering primitive. Compare-Version
    # handles SemanticVersion, normalised System.Version, and string fallback.
    return (Compare-Version -ReferenceVersion $ReferenceVersion -DifferenceVersion $DifferenceVersion) -eq 0
}
