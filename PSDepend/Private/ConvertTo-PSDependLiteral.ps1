function ConvertTo-PSDependLiteral {
    <#
    .SYNOPSIS
    Render a value as PowerShell source text suitable for a DependencyFile entry.

    .DESCRIPTION
    Used by Add-PSDepend to serialize field values (Tags, Parameters, ...) when
    writing a new hashtable-form entry. Handles strings, booleans, numbers,
    arrays, and nested hashtables.

    .PARAMETER Value
    The value to render.

    .PARAMETER IndentLevel
    Indentation depth, in 4-space units, for a nested hashtable's members and
    its closing brace.

    .EXAMPLE
    ConvertTo-PSDependLiteral -Value @{ SkipPublisherCheck = $true }

    Returns "@{`r`n        SkipPublisherCheck = `$true`r`n    }"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        $Value,

        [int]$IndentLevel = 2
    )

    if ($null -eq $Value) {
        return '$null'
    }
    if ($Value -is [bool]) {
        return $(if ($Value) { '$true' } else { '$false' })
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $ChildIndent = '    ' * ($IndentLevel + 1)
        $ClosingIndent = '    ' * $IndentLevel
        $Entries = foreach ($Key in $Value.Keys) {
            $QuotedKey = "'$($Key.ToString() -replace "'", "''")'"
            "$ChildIndent$QuotedKey = $(ConvertTo-PSDependLiteral -Value $Value[$Key] -IndentLevel ($IndentLevel + 1))"
        }
        return "@{`r`n$($Entries -join "`r`n")`r`n$ClosingIndent}"
    }
    if ($Value -is [string]) {
        return "'$($Value -replace "'", "''")'"
    }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double]) {
        return "$Value"
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $Items = @($Value | ForEach-Object { ConvertTo-PSDependLiteral -Value $_ -IndentLevel $IndentLevel })
        if ($Items.Count -eq 0) {
            return '@()'
        }
        return ($Items -join ', ')
    }
    return "'$($Value.ToString() -replace "'", "''")'"
}
