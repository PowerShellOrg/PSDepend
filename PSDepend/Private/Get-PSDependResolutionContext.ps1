function Get-PSDependResolutionContext {
    <#
    .SYNOPSIS
    Fingerprint the dependency metadata that can affect version resolution.

    .DESCRIPTION
    Produces a stable SHA-256 fingerprint from Source and Parameters without
    writing either value to the lock file. Dictionary keys are sorted so
    equivalent hashtables produce the same fingerprint regardless of insertion
    order. Target is deliberately excluded because it affects installation,
    not version resolution.

    .PARAMETER Dependency
    The PSDepend Dependency to fingerprint.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Dependency
    )

    function ConvertTo-CanonicalValue {
        param($Value)

        if ($Value -is [System.Collections.IDictionary]) {
            $result = [ordered]@{}
            foreach ($key in @($Value.Keys | Sort-Object)) {
                $result[[string]$key] = ConvertTo-CanonicalValue -Value $Value[$key]
            }
            return $result
        }
        if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
            return @($Value | ForEach-Object { ConvertTo-CanonicalValue -Value $_ })
        }
        $Value
    }

    $context = [ordered]@{
        source     = $Dependency.Source
        parameters = ConvertTo-CanonicalValue -Value $Dependency.Parameters
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $context -Compress -Depth 20))
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha256.ComputeHash($bytes)
    }
    finally {
        $sha256.Dispose()
    }
    -join ($hash | ForEach-Object { $_.ToString('x2') })
}
