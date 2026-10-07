function Join-VersionRange {
    <#
    .SYNOPSIS
    Intersect several version constraints into a single NuGet range string.

    .DESCRIPTION
    When a lock is resolved, one package can be constrained by several parents
    (and by the DependencyFile itself). Each DependencyScript only understands
    a single Version string, so the constraints are intersected here first.

    Empty strings and 'latest' impose no constraint. Exact versions must agree
    with each other and satisfy every range. Ranges are intersected bound by
    bound: the highest lower bound and lowest upper bound win, and when bounds
    tie the exclusive one is kept because it is stricter. Equal inclusive bounds
    collapse to an exact version.

    Returns 'latest', an exact version, or a NuGet range string. Writes a
    non-terminating error and returns nothing when the constraints conflict or
    one of them cannot be parsed.

    .PARAMETER Range
    The constraints to intersect: 'latest', exact versions, or NuGet ranges.

    .EXAMPLE
    Join-VersionRange -Range '[1.0,3.0)', '[2.0,)'

    Returns '[2.0,3.0)'.

    .EXAMPLE
    Join-VersionRange -Range '2.5.0', '[2.0,3.0)'

    Returns '2.5.0' because the exact version lies inside the range.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [AllowNull()]
        [string[]]$Range
    )

    $constraints = @($Range | Where-Object { -not [string]::IsNullOrEmpty($_) -and $_ -ne 'latest' })
    if ($constraints.Count -eq 0) {
        return 'latest'
    }

    $parsed = foreach ($constraint in $constraints) {
        $bounds = ConvertFrom-VersionRange -Version $constraint
        if (-not $bounds) {
            return
        }
        $bounds
    }

    $exacts = @($parsed | Where-Object IsExact)
    $ranges = @($parsed | Where-Object { -not $_.IsExact })

    if ($exacts.Count -gt 0) {
        $exact = $exacts[0].Exact
        foreach ($other in $exacts) {
            if (-not (Test-VersionEquality -ReferenceVersion $exact -DifferenceVersion $other.Exact)) {
                Write-Error "Version constraints conflict: exact versions [$exact] and [$($other.Exact)] both required"
                return
            }
        }
        foreach ($constraint in $constraints) {
            if (-not (Test-VersionInRange -Version $exact -Required $constraint)) {
                Write-Error "Version constraints conflict: exact version [$exact] does not satisfy [$constraint]"
                return
            }
        }
        return $exact
    }

    $min = $null
    $minInclusive = $true
    $max = $null
    $maxInclusive = $true
    foreach ($bounds in $ranges) {
        if ($null -ne $bounds.Min) {
            $cmp = if ($null -eq $min) { 1 } else { Compare-Version -ReferenceVersion $bounds.Min -DifferenceVersion $min }
            if ($cmp -gt 0) {
                $min = $bounds.Min
                $minInclusive = $bounds.MinInclusive
            } elseif ($cmp -eq 0 -and -not $bounds.MinInclusive) {
                $minInclusive = $false
            }
        }
        if ($null -ne $bounds.Max) {
            $cmp = if ($null -eq $max) { -1 } else { Compare-Version -ReferenceVersion $bounds.Max -DifferenceVersion $max }
            if ($cmp -lt 0) {
                $max = $bounds.Max
                $maxInclusive = $bounds.MaxInclusive
            } elseif ($cmp -eq 0 -and -not $bounds.MaxInclusive) {
                $maxInclusive = $false
            }
        }
    }

    if ($null -ne $min -and $null -ne $max) {
        $cmp = Compare-Version -ReferenceVersion $min -DifferenceVersion $max
        if ($cmp -gt 0 -or ($cmp -eq 0 -and -not ($minInclusive -and $maxInclusive))) {
            Write-Error "Version constraints conflict: no version satisfies all of [$($constraints -join '], [')]"
            return
        }
        if ($cmp -eq 0) {
            return $min
        }
    }

    $open = if ($null -ne $min -and $minInclusive) { '[' } else { '(' }
    $close = if ($null -ne $max -and $maxInclusive) { ']' } else { ')' }
    "$open$min,$max$close"
}
