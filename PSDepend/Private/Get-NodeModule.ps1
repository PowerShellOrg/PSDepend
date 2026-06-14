functionGet-NodeModule {
    [CmdletBinding()]
    Param([switch]$Global)
    If ($Global -eq $true) {
        (npm ls --json --silent --global | ConvertFrom-Json).dependencies
    }
    Else {
        (npm ls --json --silent | ConvertFrom-Json).dependencies
    }
}
