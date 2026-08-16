function Test-VersionInRange {
    <#
    .SYNOPSIS
    Test whether an installed version satisfies a requested version or range.

    .DESCRIPTION
    The single entry point gallery DependencyScripts use to decide whether an
    already-installed version satisfies the request. The request may be an exact
    version (delegated to Test-VersionEquality) or a NuGet range (parsed by
    ConvertFrom-VersionRange and compared bound-by-bound with Compare-Version).

    Range semantics live here so every DependencyType evaluates a range the same
    way, regardless of what its installer accepts natively.

    .PARAMETER Version
    The concrete installed version to test.

    .PARAMETER Required
    The requested version or NuGet range string.

    .EXAMPLE
    Test-VersionInRange -Version '2.5.0' -Required '[2.2.3,3.0)'

    Returns $true (2.5.0 falls within the range).

    .EXAMPLE
    Test-VersionInRange -Version '3.0.0' -Required '[2.2.3,3.0)'

    Returns $false (the upper bound is exclusive).

    .EXAMPLE
    Test-VersionInRange -Version '3.2.1' -Required '3.2.1'

    Returns $true (exact match).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$Version,
        [string]$Required
    )

    if ([string]::IsNullOrEmpty($Version) -or [string]::IsNullOrEmpty($Required)) {
        return $false
    }

    $range = ConvertFrom-VersionRange -Version $Required -ErrorAction SilentlyContinue
    if (-not $range) {
        return $false
    }

    if ($range.IsExact) {
        return Test-VersionEquality -ReferenceVersion $Version -DifferenceVersion $range.Exact
    }

    if ($null -ne $range.Min) {
        $lower = Compare-Version -ReferenceVersion $Version -DifferenceVersion $range.Min
        $satisfiesMin = if ($range.MinInclusive) { $lower -ge 0 } else { $lower -gt 0 }
        if (-not $satisfiesMin) {
            return $false
        }
    }

    if ($null -ne $range.Max) {
        $upper = Compare-Version -ReferenceVersion $Version -DifferenceVersion $range.Max
        $satisfiesMax = if ($range.MaxInclusive) { $upper -le 0 } else { $upper -lt 0 }
        if (-not $satisfiesMax) {
            return $false
        }
    }

    return $true
}
