function Invoke-DependencyScript {
    <#
    .SYNOPSIS
        Invoke a dependency script

    .DESCRIPTION
        Invoke a dependency script

        See Get-Help about_PSDepend for more information.

    .PARAMETER Dependency
        Dependency object from Get-Dependency.

    .PARAMETER PSDependTypePath
        Specify a PSDependMap.psd1 file that maps DependencyTypes to their scripts.

        This defaults to the PSDependMap.psd1 in the PSDepend module folder

    .PARAMETER Tags
        Only test dependencies that are tagged with all of the specified Tags (-and, not -or)

    .PARAMETER PSDependAction
        PSDependAction to run.  Test, Install, and Import are the most common.

        Test can only be run by itself.

    .PARAMETER Quiet
        If PSDependAction is Test, and Quiet is specified, we return $true or $false based on whether a dependency exists

    .EXAMPLE
        Get-Dependency -Path C:\requirements.psd1 | Import-Dependency

        Get dependencies from C:\requirements.psd1 and import them

    .LINK
        https://github.com/PowerShellOrg/PSDepend
    #>
    [cmdletbinding()]
    param(
        [parameter( ValueFromPipeline = $True,
            ParameterSetName='Map',
            Mandatory = $True)]
        [PSTypeName('PSDepend.Dependency')]
        [psobject]$Dependency,

        [validatescript({ Test-Path -Path $_ -PathType Leaf -ErrorAction Stop })]
        [string]$PSDependTypePath = $(Join-Path $ModuleRoot PSDependMap.psd1),

        [string[]]$PSDependAction,

        [string[]]$Tags,

        [switch]$Quiet
    )
    begin {
        # This script reads a depend.psd1, installs dependencies as defined
        Write-Verbose "Running Invoke-DependencyScript with ParameterSetName '$($PSCmdlet.ParameterSetName)' and params: $($PSBoundParameters | Out-String)"
        $PSDependTypes = Get-PSDependType -SkipHelp
    }
    process {
        Write-Verbose "Dependencies:`n$($Dependency | Select-Object -Property * | Out-String)"

        #Get definitions, and dependencies in this particular psd1
        $DependencyDefs = Get-PSDependScript
        $TheseDependencyTypes = @( $Dependency.DependencyType | Sort-Object -Unique )

        #Build up hash, we call each dependencytype script for applicable dependencies
        foreach($DependencyType in $TheseDependencyTypes) {
            $PSDependType = ($PSDependTypes | Where-Object { $_.DependencyType -eq $DependencyType })
            if(-not $PSDependType.Supported) {
                Write-Warning "Skipping dependency type [$DependencyType]`nThis dependency does not support your platform`nSupported platforms: [$($PSDependType.Supports)]"
                continue
            }
            $DependencyScript = $DependencyDefs.$DependencyType
            if(-not $DependencyScript) {
                Write-Error "DependencyType $DependencyType is not defined in PSDependMap.psd1"
                continue
            }
            $TheseDependencies = @( $Dependency | Where-Object { $_.DependencyType -eq $DependencyType })

            #Define params for the script
            #Each dependency type can have a hashtable to splat.
            $RawParameters = Get-Parameter -Command $DependencyScript
            $ValidParamNames = $RawParameters.Name
            Write-Verbose "Found parameters [$ValidParamNames]"

            if($ValidParamNames -notcontains 'PSDependAction') {
                Write-Error "No PSDependAction found on PSDependScript [$DependencyScript]. Skipping [$($Dependency.DependencyName)]"
                continue
            }
            [string[]]$ValidPSDependActions = $RawParameters |
                Where-Object { $_.Name -like 'PSDependAction' } |
                Select-Object -ExpandProperty ValidateSetValues -ErrorAction SilentlyContinue
            [string[]]$PSDependActions = foreach($Action in $PSDependAction) {
                if($ValidPSDependActions -contains $Action) {
                    $Action
                } else {
                    Write-Warning "Skipping PSDependAction [$Action] for dependency [$($Dependency.DependencyName)]. Valid actions: [$ValidPSDependActions]"
                }
            }

            if($PSDependActions.count -like 0) {
                Write-Verbose "Skipped dependency [$($Dependency.DependencyName)] due to filtered PSDependAction.  See Warnings above."
                continue
            }

            if($PSDependActions -contains 'Test' -and ( $PSDependActions -contains 'Import' -or $PSDependActions -contains 'Install')) {
                Write-Error "Removing [Test] from PSDependActions.  The Test action must run on its own."
                $PSDependActions = $PSDependActions | Where-Object { $_ -ne 'Test' }
            }

            foreach($ThisDependency in $TheseDependencies) {
                #Parameters for dependency types.  Only accept valid params...
                if($ThisDependency.Parameters.keys.count -gt 0) {
                    $splat = @{}
                    foreach($key in $ThisDependency.Parameters.keys) {
                        if($ValidParamNames -contains $key) {
                            $splat.Add($key, $ThisDependency.Parameters.$key)
                        } else {
                            Write-Warning "Parameter [$Key] with value [$($ThisDependency.Parameters.$Key)] is not a valid parameter for [$DependencyType], ignoring.  Valid params:`n[$ValidParamNames]"
                        }
                    }

                    if($ThisDependency.Parameters.Import -and $PSDependActions -notcontains 'Test') {
                        $PSDependActions += 'Import'
                        $PSDependActions = $PSDependActions | Sort-Object -Unique
                    } 

                    if($splat.ContainsKey('PSDependAction')) {
                        $Splat['PSDependAction'] = $PSDependActions
                    } else {
                        $Splat.add('PSDependAction', $PSDependActions)
                    }
                } else {
                    $splat = @{PSDependAction = $PSDependActions }
                }

                #Define params for the script
                $splat.add('Dependency', $ThisDependency)

                # PITA, but tasks can run two ways, each different than typical dependency scripts
                if($PSDependActions -contains 'Install' -and $DependencyType -eq 'Task') {
                    foreach($TaskScript in $ThisDependency.Target) {
                        if( Test-Path $TaskScript -PathType Leaf) {
                            . $TaskScript @splat
                        } else {
                            Write-Error "Could not process task [$TaskScript].`nAre connectivity, privileges, and other needs met to access it?"
                        }
                    }
                } else {
                    Write-Verbose "Invoking '$DependencyScript' with parameters $($Splat | Out-String)"
                    $Output = . $DependencyScript @splat
                    if($PSDependActions -contains 'Test' -and -not $Quiet) {
                        Add-Member -InputObject $ThisDependency -MemberType NoteProperty -Name DependencyExists -Value $Output -Force -PassThru
                    } else {
                        $Output
                    }
                }
            }
        }
    }
}
