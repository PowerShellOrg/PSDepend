# cspell:ignore parameterset
functionGet-ParameterName {
    #Get parameter names for a specific command
    [CmdletBinding()]
    param(
        [string]$command,
        [string]$parameterset = $null,
        [string[]]$excludeDefault = $( "Verbose",
            "Debug",
            "ErrorAction",
            "WarningAction",
            "ErrorVariable",
            "WarningVariable",
            "OutVariable",
            "OutBuffer",
            "PipelineVariable",
            "Confirm",
            "Whatif" ),
        [string[]]$exclude = $( "PassThru", "Commit" )
    )
    if ($parameterset) {
        ((Get-Command -Name $command).ParameterSets | Where-Object { $_.name -eq $parameterset } ).Parameters.Name | Where-Object { ($exclude + $excludeDefault) -notcontains $_ }
    }

    else {
        ((Get-Command -Name $command).ParameterSets | Where-Object { $_.name -eq "__AllParameterSets" } ).Parameters.Name | Where-Object { ($exclude + $excludeDefault) -notcontains $_ }
    }
}
