<#
    .SYNOPSIS
        Test double for a DependencyScript that supports the Resolve action.

    .DESCRIPTION
        Serves a static package graph so lock tests can exercise
        Update-PSDependLock, Get-Dependency and Invoke-PSDepend without a network.

        Install appends "<Name>@<Version>" to <Target>/installed.log so tests can
        observe what was installed and in which order. Test always returns $false.

    .PARAMETER Dependency
        Dependency to process

    .PARAMETER PSDependAction
        Test, Install, or Resolve.
#>
[CmdletBinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [PSObject[]]$Dependency,

    [ValidateSet('Test', 'Install', 'Resolve')]
    [string[]]$PSDependAction = @('Install')
)

# name -> version -> dependencies (NuGet ranges)
$Graph = @{
    App  = [ordered]@{
        '1.0.0' = @{ Lib = '[1.0,2.0)'; Util = 'latest' }
        '1.1.0' = @{ Lib = '[1.5,2.0)'; Util = '[2.0,)' }
        '2.0.0' = @{ Lib = '[2.0,)' }
    }
    Lib  = [ordered]@{
        '1.0.0' = @{}
        '1.5.0' = @{ Core = '[1.0,)' }
        '1.9.0' = @{ Core = '[1.0,)' }
        '2.0.0' = @{ Core = '[2.0,)' }
    }
    Util = [ordered]@{
        '1.0.0' = @{ Lib = '[1.0,1.6)' }
        '2.0.0' = @{ Lib = '[1.0,1.6)' }
    }
    Core = [ordered]@{
        '1.0.0' = @{}
        '2.0.0' = @{}
    }
}

$Name = if ($Dependency.Name) { $Dependency.Name } else { $Dependency.DependencyName }
$Version = if ($Dependency.Version) { $Dependency.Version } else { 'latest' }

if ($PSDependAction -contains 'Resolve') {
    if (-not $Graph.ContainsKey($Name)) {
        Write-Error "No package [$Name] in the fake feed"
        return
    }
    $candidates = @($Graph[$Name].Keys)
    $resolved = if ($Version -eq 'latest') {
        $candidates[-1]
    } else {
        Resolve-VersionInRange -Candidate $candidates -Required $Version
    }
    if (-not $resolved) {
        Write-Error "No version of [$Name] at [fake] satisfies [$Version]"
        return
    }
    [PSCustomObject]@{
        PSTypeName   = 'PSDepend.ResolvedDependency'
        Name         = $Name
        Version      = $resolved
        Dependencies = $Graph[$Name][$resolved]
    }
    return
}

if ($PSDependAction -contains 'Test') {
    return $false
}

if ($PSDependAction -contains 'Install') {
    $null = New-Item -ItemType Directory -Path $Dependency.Target -Force
    Add-Content -Path (Join-Path $Dependency.Target 'installed.log') -Value "$Name@$Version"
}
