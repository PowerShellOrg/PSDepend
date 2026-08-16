function Compare-Version {
    <#
    .SYNOPSIS
    Order two version strings, returning -1, 0, or 1.

    .DESCRIPTION
    Coerce both version strings to a common comparable type and compare them via
    [IComparable]. SemanticVersion is tried first so pre-release ordering is
    honoured (e.g. 1.0.0-alpha sorts below 1.0.0); System.Version is the
    fallback so four-part versions (1.2.3.4) still compare. Missing System.Version
    components are normalised to 0 so 1.2.3 and 1.2.3.0 compare equal. If neither
    type can parse both inputs, fall back to an ordinal string comparison.

    Both operands must coerce to the same type - a SemanticVersion cannot be
    compared to a System.Version - so each branch requires both inputs to parse.

    .PARAMETER ReferenceVersion
    The version on the left of the comparison.

    .PARAMETER DifferenceVersion
    The version on the right of the comparison.

    .EXAMPLE
    Compare-Version -ReferenceVersion '1.2.0' -DifferenceVersion '1.2.3'

    Returns -1 (1.2.0 is less than 1.2.3).

    .EXAMPLE
    Compare-Version -ReferenceVersion '1.0.0' -DifferenceVersion '1.0.0-beta'

    Returns 1 (a release sorts above its pre-release).
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [string]$ReferenceVersion,
        [string]$DifferenceVersion
    )

    # SemanticVersion first: it orders pre-release labels correctly.
    [System.Management.Automation.SemanticVersion]$refSemVer = $null
    [System.Management.Automation.SemanticVersion]$diffSemVer = $null
    if (
        [System.Management.Automation.SemanticVersion]::TryParse($ReferenceVersion, [ref]$refSemVer) -and
        [System.Management.Automation.SemanticVersion]::TryParse($DifferenceVersion, [ref]$diffSemVer)
    ) {
        return $refSemVer.CompareTo($diffSemVer)
    }

    # System.Version fallback handles four-part versions SemVer rejects.
    # Normalise absent components (-1) to 0 so 1.2.3 equals 1.2.3.0.
    [System.Version]$refVer = $null
    [System.Version]$diffVer = $null
    if (
        [System.Version]::TryParse($ReferenceVersion, [ref]$refVer) -and
        [System.Version]::TryParse($DifferenceVersion, [ref]$diffVer)
    ) {
        $refNormalised = [System.Version]::new(
            [Math]::Max($refVer.Major, 0),
            [Math]::Max($refVer.Minor, 0),
            [Math]::Max($refVer.Build, 0),
            [Math]::Max($refVer.Revision, 0)
        )
        $diffNormalised = [System.Version]::new(
            [Math]::Max($diffVer.Major, 0),
            [Math]::Max($diffVer.Minor, 0),
            [Math]::Max($diffVer.Build, 0),
            [Math]::Max($diffVer.Revision, 0)
        )
        return $refNormalised.CompareTo($diffNormalised)
    }

    # Neither type parses both: ordinal string comparison, clamped to -1/0/1.
    # Trace this: a wrong answer here (e.g. a typo'd '1.2.x') is otherwise silent.
    Write-Verbose "Compare-Version falling back to ordinal string comparison for [$ReferenceVersion] vs [$DifferenceVersion]"
    return [Math]::Sign(
        [string]::Compare($ReferenceVersion, $DifferenceVersion, [System.StringComparison]::OrdinalIgnoreCase)
    )
}
