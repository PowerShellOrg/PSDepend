function Add-ToItemCollection {
    param(
        $Delimiter = [IO.Path]::PathSeparator,
        $Reference, # e.g. ENV:Path
        $Item, # e.g. 'C:\Project',
        [switch]$Append
    )

    $Existing = ( Get-Item -Path $Reference ).Value -split $Delimiter | Where-Object { $_ -ne $Item }
    if ($Append) {
        $ToAdd = ( @($Existing) + $Item | Select-Object -Unique ) -join $Delimiter
    }
    else {
        $ToAdd = ( @($Item) + @($Existing) | Select-Object -Unique ) -join $Delimiter
    }
    Set-Item -Path $Reference -Value $ToAdd
}
