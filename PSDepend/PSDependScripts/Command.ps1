<#
    .SYNOPSIS
        Invoke a PowerShell command

    .DESCRIPTION
        Invoke a PowerShell command

        Converts the provided string into a scriptblock, invokes it in the current session.  Beware quoting rules

        If a terminating error occurs, we write it and continue processing.  Use FailOnError to change this.

        Relevant Dependency metadata:
            Source: The code to run
            Parameters:
                FailOnError: If specified, throw a terminating error if the command errors out.

    .PARAMETER PSDependAction
        Only option is to install the module.  Defaults to Install

        Install: Install the dependency

    .PARAMETER Dependency
        Dependency to process

    .PARAMETER FailOnError
        If specified, throw a terminating error if the command errors out

    .EXAMPLE
        @{
            ExampleCommand = @{
                DependencyType = 'Command'
                Source = '$x = hostname; "Running a command on $x"'
            }
        }

        # Run some aribtrary PowerShell code that assigns a variable and uses it in a string
        # Output: Running a command on WJ-LAB
#>
[cmdletbinding()]
param (
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [switch]$FailOnError,

    [ValidateSet('Install')]
    [string[]]$PSDependAction = @('Install') # No logic for this
)

Write-Verbose "Executing $($Dependency.count) commands"

foreach ($Depend in $Dependency) {
    foreach ($Command in $Depend.Source) {
        Write-Verbose "Invoking command [$($Depend.DependencyName)]:`n$Command"
        $ScriptBlock = [ScriptBlock]::Create($Command)
        Try {
            . $ScriptBlock
        }
        Catch {
            if ($FailOnError) {
                throw $_
            }
            else {
                Write-Error $_
                continue
            }
        }
    }
}
