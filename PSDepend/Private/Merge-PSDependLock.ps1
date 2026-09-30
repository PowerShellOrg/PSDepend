function Merge-PSDependLock {
    <#
    .SYNOPSIS
    Apply a lock to the Dependencies parsed from its DependencyFile.

    .DESCRIPTION
    First verifies the lock still describes the DependencyFile: every
    Dependency in the file must appear in the lock with the same
    DependencyType, Name and requested Version, and the lock must not list
    Dependencies the file no longer has. Any drift throws, mirroring npm ci,
    so a stale lock is never silently installed.

    Then, for each locked Dependency, the requested Version is replaced by the
    exact locked version and the locked transitive packages are materialised as
    additional Dependency objects (named Name@Version) cloned from the
    Dependency that pulled them in, with DependsOn edges so children install
    before parents. A package required by several parents is emitted once.
    Dependencies whose type could not be locked pass through untouched.

    .PARAMETER Dependency
    The Dependencies parsed from one DependencyFile.

    .PARAMETER Lock
    The lock object from Import-PSDependLock.

    .PARAMETER LockPath
    Path of the lock file, used in error messages.

    .EXAMPLE
    Merge-PSDependLock -Dependency $deps -Lock (Import-PSDependLock $lockPath) -LockPath $lockPath
    #>
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param(
        [PSTypeName('PSDepend.Dependency')]
        [PSObject[]]$Dependency,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Lock,

        [Parameter(Mandatory)]
        [string]$LockPath
    )

    $dependencyFile = $Dependency[0].DependencyFile

    # Stale check: the lock's view of the DependencyFile must match what was parsed
    $problems = New-Object System.Collections.ArrayList
    $seen = @{}
    foreach ($root in $Dependency) {
        $seen[$root.DependencyName] = $true
        $name = if ($root.Name) { $root.Name } else { $root.DependencyName }
        $requested = if ([string]::IsNullOrEmpty($root.Version)) { 'latest' } else { [string]$root.Version }
        if (-not $Lock.dependencies.Contains($root.DependencyName)) {
            $null = $problems.Add("[$($root.DependencyName)] is not in the lock")
            continue
        }
        $entry = $Lock.dependencies[$root.DependencyName]
        if ($entry.dependencyType -ne $root.DependencyType -or $entry.name -ne $name -or $entry.requested -ne $requested) {
            $null = $problems.Add("[$($root.DependencyName)] changed: lock has [$($entry.dependencyType)] [$($entry.name)] [$($entry.requested)], file has [$($root.DependencyType)] [$name] [$requested]")
        }
    }
    foreach ($lockedName in $Lock.dependencies.Keys) {
        if (-not $seen.ContainsKey($lockedName)) {
            $null = $problems.Add("[$lockedName] is in the lock but not in the DependencyFile")
        }
    }
    if ($problems.Count -gt 0) {
        throw "Lock file [$LockPath] is out of date with [$dependencyFile]:`n - $($problems -join "`n - ")`nRun Update-PSDependLock -Path '$dependencyFile' to refresh it, or use -IgnoreLock to resolve without it."
    }

    $rootByKey = @{}
    foreach ($root in $Dependency) {
        $entry = $Lock.dependencies[$root.DependencyName]
        if ($entry.Contains('resolved') -and -not $rootByKey.ContainsKey($entry.resolved)) {
            $rootByKey[$entry.resolved] = $root
        }
    }

    $synthesized = [ordered]@{}

    function Get-LockedPackage {
        param([string]$Key)
        if (-not $Lock.packages.Contains($Key)) {
            throw "Lock file [$LockPath] is corrupt: package [$Key] is referenced but not locked. Run Update-PSDependLock -Path '$dependencyFile' to regenerate it."
        }
        $Lock.packages[$Key]
    }

    # Returns the DependencyName that represents $Key, creating a synthesized
    # Dependency (and, recursively, its children) when it is not a root.
    function Resolve-LockedChild {
        param([string]$Key, [PSObject]$Template)
        if ($rootByKey.ContainsKey($Key)) {
            return $rootByKey[$Key].DependencyName
        }
        if ($synthesized.Contains($Key)) {
            return $synthesized[$Key].DependencyName
        }
        $package = Get-LockedPackage -Key $Key
        $name = $Key.Substring($Key.IndexOf('::') + 2)
        $child = [PSCustomObject]@{
            PSTypeName      = 'PSDepend.Dependency'
            DependencyFile  = $Template.DependencyFile
            DependencyName  = "$name@$($package.version)"
            DependencyType  = $Template.DependencyType
            Name            = $name
            Version         = $package.version
            Parameters      = $Template.Parameters
            Source          = $Template.Source
            Target          = $Template.Target
            AddToPath       = $Template.AddToPath
            Tags            = $Template.Tags
            DependsOn       = $null
            PreScripts      = $null
            PostScripts     = $null
            Credential      = $Template.Credential
            PSDependOptions = $Template.PSDependOptions
            Raw             = $null
        }
        $synthesized[$Key] = $child
        $child.DependsOn = Get-LockedChildList -Package $package -DependencyType $Template.DependencyType -Template $Template
        $child.DependencyName
    }

    function Get-LockedChildList {
        param($Package, [string]$DependencyType, [PSObject]$Template)
        $names = foreach ($childName in $Package.dependencies.Keys) {
            Resolve-LockedChild -Key "${DependencyType}::$childName" -Template $Template
        }
        if ($names) { @($names) } else { $null }
    }

    foreach ($root in $Dependency) {
        $entry = $Lock.dependencies[$root.DependencyName]
        if (-not $entry.Contains('resolved')) {
            continue
        }
        $package = Get-LockedPackage -Key $entry.resolved
        Write-Verbose "Lock pins [$($root.DependencyName)] to [$($package.version)] (requested [$($entry.requested)])"
        $root.Version = $package.version
        $children = Get-LockedChildList -Package $package -DependencyType $root.DependencyType -Template $root
        if ($children) {
            $root.DependsOn = @(@($root.DependsOn) + $children | Where-Object { $_ } | Select-Object -Unique)
        }
    }

    $Dependency
    $synthesized.Values
}
