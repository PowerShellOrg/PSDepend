function Find-NodeModule {
    <#
    .SYNOPSIS
    Query the npm registry for the published versions of a package.

    .DESCRIPTION
    Runs `npm view <package>[@<version>] version --json` and returns the matching
    version strings. npm prints a single JSON string when one version matches and a
    JSON array when several do; both are normalized to [string[]].

    Writes an error and returns nothing when npm is not on PATH.

    .PARAMETER PackageName
    The npm package name.

    .PARAMETER Version
    Optional npm version or range spec. Empty or 'latest' lists every published version.

    .EXAMPLE
    Find-NodeModule -PackageName 'left-pad' -Version '1.3.0'

    Returns '1.3.0' when that version is published.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [string]$PackageName,
        [string]$Version
    )

    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Error "npm was not found on PATH; cannot query versions for [$PackageName]"
        return
    }

    if ([string]::IsNullOrEmpty($Version) -or $Version -eq 'latest') {
        $json = npm view --json -- $PackageName version
    } else {
        $json = npm view --json -- "$PackageName@$Version" version
    }

    if ([string]::IsNullOrWhiteSpace(($json -join ''))) {
        return
    }

    [string[]]@(($json -join "`n") | ConvertFrom-Json)
}
