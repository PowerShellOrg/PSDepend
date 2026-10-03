function Import-PSDependLock {
    <#
    .SYNOPSIS
    Read a lock file back into the same shape Resolve-PSDependLock produces.

    .DESCRIPTION
    Parses the JSON lock and returns an ordered hashtable with lockfileVersion,
    dependencies and packages. Throws when the file is not a PSDepend lock or
    was written by a newer, unsupported lockfileVersion.

    .PARAMETER Path
    Path to the lock file.

    .EXAMPLE
    Import-PSDependLock -Path .\requirements.lock.json
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    function ConvertTo-OrderedHashtable {
        param($InputObject)
        if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
            $table = [ordered]@{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $table[$property.Name] = ConvertTo-OrderedHashtable $property.Value
            }
            return $table
        }
        $InputObject
    }


    function Assert-Table {
        param($Value, [string]$Description)

        if ($Value -isnot [System.Collections.IDictionary]) {
            throw "Lock file [$Path] is corrupt: $Description must be a JSON object"
        }
    }

    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    try {
        $parsed = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
    } catch {
        throw "Lock file [$Path] is not valid JSON: $_"
    }
    $lock = ConvertTo-OrderedHashtable $parsed

    if ($lock -isnot [System.Collections.IDictionary]) {
        throw "Lock file [$Path] is not a PSDepend lock file (the top level must be a JSON object)"
    }
    if (-not $lock.Contains('lockfileVersion') -or -not $lock.Contains('dependencies') -or -not $lock.Contains('packages')) {
        throw "Lock file [$Path] is not a PSDepend lock file (missing lockfileVersion, dependencies or packages)"
    }
    if ($lock.lockfileVersion -ne 1) {
        throw "Lock file [$Path] uses lockfileVersion [$($lock.lockfileVersion)]; this version of PSDepend supports lockfileVersion 1. Regenerate it with Update-PSDependLock"
    }

    Assert-Table -Value $lock.dependencies -Description 'dependencies'
    Assert-Table -Value $lock.packages -Description 'packages'

    foreach ($dependencyName in $lock.dependencies.Keys) {
        $entry = $lock.dependencies[$dependencyName]
        Assert-Table -Value $entry -Description "dependency [$dependencyName]"
        foreach ($requiredProperty in 'dependencyType', 'name', 'requested') {
            if (-not $entry.Contains($requiredProperty) -or [string]::IsNullOrWhiteSpace([string]$entry[$requiredProperty])) {
                throw "Lock file [$Path] is corrupt: dependency [$dependencyName] has no [$requiredProperty]"
            }
        }
        if ($entry.Contains('contextHash') -and [string]$entry.contextHash -notmatch '^[0-9a-f]{64}$') {
            throw "Lock file [$Path] is corrupt: dependency [$dependencyName] has an invalid resolution context hash"
        }
        if ($entry.Contains('resolved')) {
            $expectedKey = "$($entry.dependencyType)::$($entry.name)"
            if ($entry.resolved -cne $expectedKey) {
                throw "Lock file [$Path] is corrupt: dependency [$dependencyName] has resolved key [$($entry.resolved)]; expected [$expectedKey]"
            }
            if (-not $lock.packages.Contains($entry.resolved)) {
                throw "Lock file [$Path] is corrupt: dependency [$dependencyName] references package [$($entry.resolved)], which is not locked"
            }
        }
    }

    foreach ($packageKey in $lock.packages.Keys) {
        if ([string]$packageKey -notmatch '^([^:]+)::([A-Za-z0-9@][A-Za-z0-9._/@-]*)$') {
            throw "Lock file [$Path] is corrupt: package key [$packageKey] is not a valid DependencyType::Name"
        }
        $dependencyType = $Matches[1]
        $package = $lock.packages[$packageKey]
        Assert-Table -Value $package -Description "package [$packageKey]"
        if (-not $package.Contains('version') -or -not (Test-PSDependExactVersion -Version ([string]$package.version))) {
            throw "Lock file [$Path] is corrupt: package [$packageKey] must have an exact version"
        }
        if (-not $package.Contains('dependencies')) {
            throw "Lock file [$Path] is corrupt: package [$packageKey] has no dependencies object"
        }
        Assert-Table -Value $package.dependencies -Description "dependencies of package [$packageKey]"
        foreach ($childName in $package.dependencies.Keys) {
            if ([string]$childName -notmatch '^[A-Za-z0-9@][A-Za-z0-9._/@-]*$') {
                throw "Lock file [$Path] is corrupt: package [$packageKey] has invalid dependency name [$childName]"
            }
            $childKey = "${dependencyType}::$childName"
            if (-not $lock.packages.Contains($childKey)) {
                throw "Lock file [$Path] is corrupt: package [$packageKey] references [$childKey], which is not locked"
            }
        }
    }

    $lock
}
