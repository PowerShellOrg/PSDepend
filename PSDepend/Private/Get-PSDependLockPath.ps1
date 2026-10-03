function Get-PSDependLockPath {
    <#
    .SYNOPSIS
    Return the lock file path that belongs to a DependencyFile.

    .DESCRIPTION
    The lock lives next to its DependencyFile with the .psd1 extension replaced
    by .lock.json: requirements.psd1 -> requirements.lock.json,
    build.depend.psd1 -> build.depend.lock.json.

    .PARAMETER DependencyFile
    Full path to the DependencyFile.

    .EXAMPLE
    Get-PSDependLockPath -DependencyFile C:\proj\requirements.psd1

    Returns C:\proj\requirements.lock.json.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$DependencyFile
    )

    [System.IO.Path]::ChangeExtension($DependencyFile, '.lock.json')
}
