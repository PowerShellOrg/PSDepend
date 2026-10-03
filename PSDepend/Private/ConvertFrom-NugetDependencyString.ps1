# cspell:ignore Newtonsoft
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

    When the same id appears under several target frameworks, identical ranges
    are collapsed. Different ranges are rejected because PSDepend cannot know
    which target framework the eventual NuGet installation will select.

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
    $frameworks = @{}
    if ([string]::IsNullOrWhiteSpace($Dependencies)) {
        return $map
    }

    foreach ($entry in $Dependencies -split '\|') {
        $parts = $entry -split ':', 3
        $id = $parts[0].Trim()
        if (-not $id) {
            continue
        }

        $range = if ($parts.Count -gt 1) { $parts[1] -replace '\s', '' } else { '' }
        if (-not $range) {
            $range = 'latest'
        }
        elseif ($range -notmatch '[\[\](),]') {
            $range = "[$range,)"
        }

        $framework = if ($parts.Count -gt 2 -and $parts[2]) { $parts[2].Trim() } else { '<any>' }
        if ($map.ContainsKey($id)) {
            if ($map[$id] -ne $range) {
                throw "NuGet dependency [$id] has different constraints [$($map[$id])] for [$($frameworks[$id])] and [$range] for [$framework]; target-framework-specific dependency groups cannot be locked safely"
            }
            continue
        }

        $map[$id] = $range
        $frameworks[$id] = $framework
    }

    $map
}
