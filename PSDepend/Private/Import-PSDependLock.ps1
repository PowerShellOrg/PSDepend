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

    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    try {
        $parsed = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
    } catch {
        throw "Lock file [$Path] is not valid JSON: $_"
    }
    $lock = ConvertTo-OrderedHashtable $parsed

    if (-not $lock.Contains('lockfileVersion') -or -not $lock.Contains('dependencies') -or -not $lock.Contains('packages')) {
        throw "Lock file [$Path] is not a PSDepend lock file (missing lockfileVersion, dependencies or packages)"
    }
    if ($lock.lockfileVersion -ne 1) {
        throw "Lock file [$Path] uses lockfileVersion [$($lock.lockfileVersion)]; this version of PSDepend supports lockfileVersion 1. Regenerate it with Update-PSDependLock"
    }

    $lock
}
