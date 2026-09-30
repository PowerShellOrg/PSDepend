function ConvertFrom-NugetDependencyString {
    <#
    .SYNOPSIS
    Convert a NuGet v2 OData Dependencies string into a PSDepend dependency map.

    .DESCRIPTION
    NuGet v2 feeds report package dependencies as a single string:
    entries are separated by '|', each entry is 'id:versionRange:targetFramework'
    (the range and framework may be empty; entries with an empty id are
    framework-only group markers such as '::net45' and are skipped).

    Ranges are converted to PSDepend semantics (see adr/0001):
        empty              -> 'latest'
        bracketed/parens   -> kept, with internal whitespace removed ('[1.3.3, )' -> '[1.3.3,)')
        bare version 1.0.0 -> '[1.0.0,)'  (NuGet bare means minimum inclusive; PSDepend bare means exact)

    When the same id appears under several target frameworks, the first
    occurrence wins. Null or empty input returns an empty hashtable.

    .PARAMETER Dependencies
    The raw Dependencies string from the feed's package metadata.

    .EXAMPLE
    ConvertFrom-NugetDependencyString -Dependencies 'Newtonsoft.Json:13.0.1:'

    Returns @{ 'Newtonsoft.Json' = '[13.0.1,)' }.

    .EXAMPLE
    ConvertFrom-NugetDependencyString -Dependencies 'git.install:[2.44.0]:|Foo::|::net45'

    Returns @{ 'git.install' = '[2.44.0]'; Foo = 'latest' }.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Dependencies
    )

    $map = @{}
    if ([string]::IsNullOrWhiteSpace($Dependencies)) {
        return $map
    }

    foreach ($entry in $Dependencies -split '\|') {
        $parts = $entry -split ':', 3
        $id = $parts[0].Trim()
        if (-not $id -or $map.ContainsKey($id)) {
            continue
        }

        $range = if ($parts.Count -gt 1) { $parts[1] -replace '\s', '' } else { '' }
        if (-not $range) {
            $range = 'latest'
        }
        elseif ($range -notmatch '[\[\](),]') {
            $range = "[$range,)"
        }

        $map[$id] = $range
    }

    $map
}
