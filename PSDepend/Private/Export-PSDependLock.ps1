function Export-PSDependLock {
    <#
    .SYNOPSIS
    Write a lock object to disk as JSON.

    .DESCRIPTION
    Serialises the ordered lock object produced by Resolve-PSDependLock. Keys are
    already sorted by the producer so the file diffs cleanly under source
    control. The file is written as UTF-8 without a BOM.

    .PARAMETER Lock
    The lock object from Resolve-PSDependLock.

    .PARAMETER Path
    Destination path, normally from Get-PSDependLockPath.

    .EXAMPLE
    Export-PSDependLock -Lock $lock -Path .\requirements.lock.json
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Lock,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $json = ConvertTo-Json -InputObject $Lock -Depth 10
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, $utf8)
}
