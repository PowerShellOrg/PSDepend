function Get-NodeModule {
    [CmdletBinding()]
    param([switch]$Global)
    if ($Global -eq $true) {
        (npm ls --json --silent --global | ConvertFrom-Json).dependencies
    } else {
        (npm ls --json --silent | ConvertFrom-Json).dependencies
    }
}
