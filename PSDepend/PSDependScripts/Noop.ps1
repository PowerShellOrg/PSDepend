<#
    .SYNOPSIS
        Display variables that a dependency script would receive.

        Used for testing and validation.

    .DESCRIPTION
        Display variables that a dependency script would receive.

        Used for testing and validation.

    .PARAMETER Dependency
        Dependency to process

    .PARAMETER StringParameter
        An example parameter that does nothing
#>
[cmdletbinding()]
param (
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [string[]]$StringParameter
)

Write-Verbose "Starting noop run with $($Dependency.count) sources"

[PSCustomObject]@{
    PSBoundParameters    = $PSBoundParameters
    Dependency           = $Dependency
    DependencyParameters = $Dependency.Parameters
    GetVariable          = (Get-Variable)
    ENV                  = Get-ChildItem ENV:
}