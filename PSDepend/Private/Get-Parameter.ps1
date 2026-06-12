# Borrowed from http://poshcode.org/5929 with a minor tweak for validateset - thanks all!
Function Get-Parameter {
    #.Synopsis
    #  Enumerates the parameters of one or more commands
    #.Description
    #  Lists all the parameters of a command, by ParameterSet, including their aliases, type, etc.
    #
    #  By default, formats the output to tables grouped by command and parameter set
    #.Example
    #  Get-Command Select-Xml | Get-Parameter
    #.Example
    #  Get-Parameter Select-Xml
    [CmdletBinding(DefaultParameterSetName = "ParameterName")]
    param(
        # The name of the command to get parameters for
        [Parameter(Position = 1, Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("Name")]
        [string[]]$CommandName,

        # The parameter name to filter by (allows Wilcards)
        [Parameter(Position = 2, ValueFromPipelineByPropertyName = $true, ParameterSetName = "FilterNames")]
        [string[]]$ParameterName = "*",

        # The ParameterSet name to filter by (allows wildcards)
        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "FilterSets")]
        [string[]]$SetName = "*",

        # The name of the module which contains the command (this is for scoping)
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        $ModuleName,

        # Skip testing for Provider parameters (will be much faster)
        [Switch]$SkipProviderParameters,

        # Forces including the CommonParameters in the output
        [switch]$Force
    )

    begin {
        $PropertySet = @( "Name",
            @{n = "Position"; e = { if ($_.Position -lt 0) { "Named" }else { $_.Position } } },
            "Aliases",
            @{n = "Short"; e = { $_.Name } },
            @{n = "Type"; e = { $_.ParameterType.Name } },
            @{n = "ParameterSet"; e = { $paramset } },
            @{n = "Command"; e = { $command } },
            @{n = "Mandatory"; e = { $_.IsMandatory } },
            @{n = "Provider"; e = { $_.DynamicProvider } },
            @{n = "ValueFromPipeline"; e = { $_.ValueFromPipeline } },
            @{n = "ValueFromPipelineByPropertyName"; e = { $_.ValueFromPipelineByPropertyName } },
            "ValidateSetValues" # This is a bit specific and not always applicable, but need it for this project....
        )
        function Join-Object {
            Param(
                [Parameter(Position = 0)]
                $First,

                [Parameter(ValueFromPipeline = $true, Position = 1)]
                $Second
            )
            begin {
                [string[]] $p1 = $First | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name
            }
            process {
                $Output = $First | Select-Object $p1
                foreach ($p in $Second | Get-Member -MemberType Properties | Where-Object { $p1 -notcontains $_.Name } | Select-Object -ExpandProperty Name) {
                    Add-Member -InputObject $Output -MemberType NoteProperty -Name $p -Value $Second."$p"
                }
                $Output
            }
        }

        function Add-Parameters {
            [CmdletBinding()]
            param(
                [Parameter(Position = 0)]
                [Hashtable]$Parameters,

                [Parameter(Position = 1)]
                [System.Management.Automation.ParameterMetadata[]]$MoreParameters
            )

            foreach ($p in $MoreParameters | Where-Object { !$Parameters.ContainsKey($_.Name) } ) {
                Write-Debug ("INITIALLY: " + $p.Name)
                $Parameters.($p.Name) = $p | Select-Object *
            }

            [Array]$Dynamic = $MoreParameters | Where-Object { $_.IsDynamic }
            if ($dynamic) {
                foreach ($d in $dynamic) {
                    if (Get-Member -InputObject $Parameters.($d.Name) -Name DynamicProvider) {
                        Write-Debug ("ADD:" + $d.Name + " " + $provider.Name)
                        $Parameters.($d.Name).DynamicProvider += $provider.Name
                    }
                    else {
                        Write-Debug ("CREATE:" + $d.Name + " " + $provider.Name)
                        $Parameters.($d.Name) = $Parameters.($d.Name) | Select-Object *, @{ n = "DynamicProvider"; e = { @($provider.Name) } }
                    }
                }
            }
        }
    }

    process {
        foreach ($cmd in $CommandName) {
            if ($ModuleName) { $cmd = "$ModuleName\$cmd" }
            Write-Verbose "Searching for $cmd"
            $commands = @(Get-Command $cmd)

            foreach ($command in $commands) {
                Write-Verbose "Searching for $command"
                # resolve aliases (an alias can point to another alias)
                while ($command.CommandType -eq "Alias") {
                    $command = @(Get-Command ($command.definition))[0]
                }
                if (-not $command) { continue }

                Write-Verbose "Get-Parameters for $($Command.Source)\$($Command.Name)"

                $Parameters = @{}

                ## We need to detect provider parameters ...
                $NoProviderParameters = !$SkipProviderParameters
                ## Shortcut: assume only the core commands get Provider dynamic parameters
                if (!$SkipProviderParameters -and $Command.Source -eq "Microsoft.PowerShell.Management") {
                    ## The best I can do is to validate that the command has a parameter which could accept a string path
                    foreach ($param in $Command.Parameters.Values) {
                        if (([String[]], [String] -contains $param.ParameterType) -and ($param.ParameterSets.Values | Where-Object { $_.Position -ge 0 })) {
                            $NoProviderParameters = $false
                            break
                        }
                    }
                }

                if ($NoProviderParameters) {
                    if ($Command.Parameters) {
                        Add-Parameters $Parameters $Command.Parameters.Values
                    }
                }
                else {
                    foreach ($provider in Get-PSProvider) {
                        if ($provider.Drives.Length -gt 0) {
                            $drive = Get-Location -PSProvider $Provider.Name
                        }
                        else {
                            $drive = "{0}\{1}::\" -f $provider.ModuleName, $provider.Name
                        }
                        Write-Verbose ("Get-Command $command -Args $drive | Select -Expand Parameters")

                        try {
                            $MoreParameters = (Get-Command $command -Args $drive).Parameters.Values
                        }
                        catch {}

                        if ($MoreParameters.Length -gt 0) {
                            Add-Parameters $Parameters $MoreParameters
                        }
                    }
                    # If for some reason none of the drive paths worked, just use the default parameters
                    if ($Parameters.Length -eq 0) {
                        if ($Command.Parameters) {
                            Add-Parameters $Parameters $Command.Parameters.Values
                        }
                    }
                }

                ## Calculate the shortest distinct parameter name -- do this BEFORE removing the common parameters or else.
                $Aliases = $Parameters.Values | Select-Object -ExpandProperty Aliases  ## Get defined aliases
                $ParameterNames = $Parameters.Keys + $Aliases
                foreach ($p in $($Parameters.Keys)) {
                    $short = "^"
                    $aliases = @($p) + @($Parameters.$p.Aliases) | Sort-Object { $_.Length }
                    $shortest = "^" + @($aliases)[0]

                    foreach ($name in $aliases) {
                        $short = "^"
                        foreach ($char in [char[]]$name) {
                            $short += $char
                            $mCount = ($ParameterNames -match $short).Count
                            if ($mCount -eq 1 ) {
                                if ($short.Length -lt $shortest.Length) {
                                    $shortest = $short
                                }
                                break
                            }
                        }
                    }
                    if ($shortest.Length -lt @($aliases)[0].Length + 1) {
                        # Overwrite the Aliases with this new value
                        $Parameters.$p = $Parameters.$p | Add-Member NoteProperty Aliases ($Parameters.$p.Aliases + @("$($shortest.SubString(1))*")) -Force -PassThru
                    }

                    # ValidateSet...
                    $Parameters.$p = $Parameters.$p | Add-Member NoteProperty ValidateSetValues ($Parameters.$p.Attributes | Where-Object { $_.TypeId.name -like 'ValidateSetAttribute' }).ValidValues -Force -PassThru

                }

                # Write-Verbose "Parameters: $($Parameters.Count)`n $($Parameters | ft | out-string)"
                $CommonParameters = [string[]][System.Management.Automation.Cmdlet]::CommonParameters

                foreach ($paramset in @($command.ParameterSets | Select-Object -ExpandProperty "Name")) {
                    $paramset = $paramset | Add-Member -Name IsDefault -MemberType NoteProperty -Value ($paramset -eq $command.DefaultParameterSet) -PassThru
                    foreach ($parameter in $Parameters.Keys | Sort-Object) {
                        # Write-Verbose "Parameter: $Parameter"
                        if (!$Force -and ($CommonParameters -contains $Parameter)) { continue }
                        if ($Parameters.$Parameter.ParameterSets.ContainsKey($paramset) -or $Parameters.$Parameter.ParameterSets.ContainsKey("__AllParameterSets")) {
                            if ($Parameters.$Parameter.ParameterSets.ContainsKey($paramset)) {
                                $output = Join-Object $Parameters.$Parameter $Parameters.$Parameter.ParameterSets.$paramSet
                            }
                            else {
                                $output = Join-Object $Parameters.$Parameter $Parameters.$Parameter.ParameterSets.__AllParameterSets
                            }

                            Write-Output $Output | Select-Object $PropertySet | ForEach-Object {
                                $null = $_.PSTypeNames.Insert(0, "System.Management.Automation.ParameterMetadata")
                                $null = $_.PSTypeNames.Insert(0, "System.Management.Automation.ParameterMetadataEx")
                                # Write-Verbose "$(($_.PSTypeNames.GetEnumerator()) -join ", ")"
                                $_
                            } |
                                Add-Member ScriptMethod ToString { $this.Name } -Force -PassThru |
                                Where-Object { $(foreach ($pn in $ParameterName) { $_ -like $Pn }) -contains $true } |
                                Where-Object { $(foreach ($sn in $SetName) { $_.ParameterSet -like $sn }) -contains $true }
                        }
                    }
                }
            }
        }
    }
}
