# Pester wasn't mocking git...
# Borrowed idea from https://github.com/pester/Pester/issues/415
function Invoke-ExternalCommand {
    [CmdletBinding()]
    param($Command, [string[]]$Arguments, [switch]$PassThru)

    Write-Verbose "Running $Command with arguments $($Arguments -join "; ")"
    $result = $null
    $result = & $command @arguments
    Write-Verbose "$($result | Out-String)"
    if ($PassThru) {
        $Result
    }
}
