function Resolve-PSDependFileTarget {
    <#
    .SYNOPSIS
    Resolve the DependencyFile that Add-PSDepend should write to.

    .DESCRIPTION
    If Path points to an existing file, it is used as-is. If Path points to a
    nonexistent path with a .psd1 extension, it is treated as the file to
    create. Otherwise Path is treated as a directory: it is searched
    (optionally recursively) for *.depend.psd1 and requirements.psd1 files,
    the same way Invoke-PSDepend and Update-PSDependLock discover
    DependencyFiles. Exactly one match is returned as-is. No matches falls
    back to <Path>\requirements.psd1, to be created by the caller. More than
    one match is ambiguous and the caller must narrow it with -Path.

    .PARAMETER Path
    A DependencyFile, a new DependencyFile to create, or a directory to search.

    .PARAMETER Recurse
    Whether to recurse into subdirectories when Path is a directory.

    .EXAMPLE
    Resolve-PSDependFileTarget -Path . -Recurse $true

    Finds the single DependencyFile under the current directory tree, or
    falls back to .\requirements.psd1 if none exist yet.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [bool]$Recurse = $true
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        return (Resolve-Path -LiteralPath $Path).ProviderPath
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        if ([System.IO.Path]::GetExtension($Path) -eq '.psd1') {
            return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        }
        throw "Path '$Path' does not exist"
    }

    $DirectoryPath = (Resolve-Path -LiteralPath $Path).ProviderPath
    $Found = @(Resolve-DependScripts -Path $DirectoryPath -Recurse $Recurse)
    switch ($Found.Count) {
        0 { Join-Path $DirectoryPath 'requirements.psd1' }
        1 { $Found[0] }
        default {
            throw "Multiple DependencyFiles found under '$DirectoryPath': $($Found -join ', '). Specify -Path to target one of them."
        }
    }
}
