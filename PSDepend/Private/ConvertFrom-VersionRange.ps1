function ConvertFrom-VersionRange {
    <#
    .SYNOPSIS
    Parse a NuGet version range string into a structured bounds object.

    .DESCRIPTION
    PSDepend carries version ranges in the Version field using NuGet range
    syntax. A string is only treated as a range when it contains a range
    delimiter ('[', ']', '(', ')', ','); a bare version (e.g. 3.2.1) is returned
    as an exact match so existing requirements files keep their meaning.

    Returns a [PSCustomObject] with these properties:
        IsExact      - $true when the request is a single exact version
        Exact        - the exact version string (only when IsExact)
        Min          - lower bound version string, or $null for no lower bound
        Max          - upper bound version string, or $null for no upper bound
        MinInclusive - $true when the lower bound is inclusive ('[')
        MaxInclusive - $true when the upper bound is inclusive (']')

    Brackets denote inclusive bounds, parentheses exclusive. A bracketed single
    value ([1.0]) is an exact match. An empty side means that bound is open.
    Malformed ranges produce a non-terminating error and return nothing.

    .PARAMETER Version
    The version or NuGet range string to parse.

    .EXAMPLE
    ConvertFrom-VersionRange -Version '3.2.1'

    Returns an object with IsExact = $true and Exact = '3.2.1'.

    .EXAMPLE
    ConvertFrom-VersionRange -Version '[2.2.3,3.0)'

    Returns Min = '2.2.3' (inclusive), Max = '3.0' (exclusive).

    .EXAMPLE
    ConvertFrom-VersionRange -Version '(,3.0)'

    Returns Min = $null, Max = '3.0' (exclusive) - an upper-bound-only range.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [string]$Version
    )

    $exactResult = {
        param($Value)
        [PSCustomObject]@{
            IsExact      = $true
            Exact        = $Value
            Min          = $null
            Max          = $null
            MinInclusive = $true
            MaxInclusive = $true
        }
    }

    # No range delimiter: a bare version is an exact match.
    if ($Version -notmatch '[\[\](),]') {
        return & $exactResult $Version
    }

    # Bracketed/parenthesised range: first and last char carry inclusivity.
    $open = $Version[0]
    $close = $Version[-1]
    if ($open -notin '[', '(' -or $close -notin ']', ')') {
        Write-Error "Invalid version range [$Version]: must start with '[' or '(' and end with ']' or ')'."
        return
    }

    $minInclusive = $open -eq '['
    $maxInclusive = $close -eq ']'
    $inner = $Version.Substring(1, $Version.Length - 2)

    # A single value with no comma (e.g. [1.0]) is an exact match.
    if ($inner -notmatch ',') {
        $single = $inner.Trim()
        if ([string]::IsNullOrEmpty($single)) {
            Write-Error "Invalid version range [$Version]: no version specified."
            return
        }
        if (-not $minInclusive -or -not $maxInclusive) {
            Write-Error "Invalid version range [$Version]: a single version must be bracketed as [version]."
            return
        }
        return & $exactResult $single
    }

    $parts = $inner -split ',', 2
    $min = $parts[0].Trim()
    $max = $parts[1].Trim()

    if ([string]::IsNullOrEmpty($min) -and [string]::IsNullOrEmpty($max)) {
        Write-Error "Invalid version range [$Version]: at least one bound is required."
        return
    }

    [PSCustomObject]@{
        IsExact      = $false
        Exact        = $null
        Min          = if ([string]::IsNullOrEmpty($min)) { $null } else { $min }
        Max          = if ([string]::IsNullOrEmpty($max)) { $null } else { $max }
        MinInclusive = $minInclusive
        MaxInclusive = $maxInclusive
    }
}
