# cspell:ignore prestage
<#
    .SYNOPSIS
        Support dependencies by handling simple tasks.

    .DESCRIPTION
        Support dependencies by handling simple tasks.

        Relevant Dependency metadata:
            Target: One or more scripts to run for this task (Source is honored as an alias)
            Parameters: Parameters to call against the task scripts

    .PARAMETER PSDependAction
        Only option is to install the module.  Defaults to Install

        Install: Install the dependency

    .PARAMETER Dependency
        Dependency to process

    .EXAMPLE
        # Assumption: you prestage a script somewhere or include it in your solution
        Set-Content C:\Example.ps1 ' "Running a task on $(hostname)" '

        # Dependency syntax with C:\Example.ps1 already in place
        @{
            ExampleTask = @{
                DependencyType = 'Task'
                Target = 'C:\Example.ps1'
            }
        }

        # Run C:\Example.ps1
        # Output: Running a task on WJ-LAB

    .EXAMPLE

        # Dependency syntax with $PWD\Example.ps1 already in place
        @{
            ExampleTask = @{
                DependencyType = 'Task'
                Target = '$PWD\Example.ps1'
            }
        }

        # Run Example.ps1 from the current directory
        # Alternatively, you can use $DependencyPath to refer to the folder containing this dependency file
#>
[CmdletBinding()]
param (
    [PSTypeName('PSDepend.Dependency')]
    [PSObject[]]$Dependency,

    [ValidateSet('Install')]
    [string[]]$PSDependAction = @('Install') # No logic for this
)

Write-Verbose "Executing $($Dependency.count) tasks"

foreach ($Depend in $Dependency) {
    $Tasks = if ($Depend.Source) { $Depend.Source } else { $Depend.Target }
    foreach ($Task in $Tasks) {
        if (Test-Path $Task -PathType Leaf) {
            $params = @{}
            if ($Depend.Parameters) {
                $params += $Depend.Parameters
            }
            . $Task @params
        }
        else {
            Write-Warning "Could not find task file [$Task] from dependency [$($Depend.DependencyName)]"
        }
    }
}
