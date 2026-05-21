# Pester wasn't mocking git... 
# Borrowed idea from https://github.com/pester/Pester/issues/415
function Invoke-ExternalCommand {
    [cmdletbinding()]
    param($Command, [string[]]$Arguments, [switch]$Passthru)

    Write-Verbose "Running $Command with arguments $($Arguments -join "; ")"
    $result = $null
    $result = & $command @arguments  
    Write-Verbose "$($result | Out-String)"
    if ($Passthru) {
        $Result
    }
}