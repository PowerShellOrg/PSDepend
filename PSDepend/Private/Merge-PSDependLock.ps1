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
    exact locked version and the locked transitive packages are materialized as
    additional Dependency objects cloned from the Dependency that pulled them
    in. DependsOn edges ensure children install before parents. A package is
    materialized once per root so roots with different installation contexts
    each receive their transitive dependencies. Dependencies whose type could
    not be locked pass through untouched.

    .PARAMETER Dependency
    The Dependencies parsed from one DependencyFile.

    .PARAMETER Lock
    The lock object from Import-PSDependLock.

    .PARAMETER LockPath
    Path of the lock file, used in error messages.

    .PARAMETER DependencyFile
    Path of the DependencyFile represented by Dependency. Required even when
    the file contains no Dependencies so stale locks can still be rejected.

    .EXAMPLE
    Merge-PSDependLock -Dependency $deps -Lock (Import-PSDependLock $lockPath) -LockPath $lockPath
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Transforms in-memory Dependency objects; it does not change external state.'
    )]
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param(
        [AllowEmptyCollection()]
        [PSTypeName('PSDepend.Dependency')]
        [PSObject[]]$Dependency,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Lock,

        [Parameter(Mandatory)]
        [string]$LockPath,

        [Parameter(Mandatory)]
        [string]$DependencyFile
    )

    # Stale check: the lock's view of the DependencyFile must match what was parsed
    $problems = New-Object System.Collections.ArrayList
    $seen = @{}
    foreach ($root in $Dependency) {
        $seen[$root.DependencyName] = $true
        $name = if ($root.Name) { $root.Name } else { $root.DependencyName }
        $requested = Get-PSDependRequestedVersion -Version $root.Version
        $contextHash = Get-PSDependResolutionContext -Dependency $root
        if (-not $Lock.dependencies.Contains($root.DependencyName)) {
            $null = $problems.Add("[$($root.DependencyName)] is not in the lock")
            continue
        }
        $entry = $Lock.dependencies[$root.DependencyName]
        if ($entry.dependencyType -ne $root.DependencyType -or $entry.name -ne $name -or $entry.requested -ne $requested) {
            $null = $problems.Add(
                "[$($root.DependencyName)] changed: lock has [$($entry.dependencyType)] [$($entry.name)] [$($entry.requested)], " +
                "file has [$($root.DependencyType)] [$name] [$requested]"
            )
        }
        if ($entry.contextHash -ne $contextHash) {
            $null = $problems.Add("[$($root.DependencyName)] resolution source or parameters changed")
        }
    }
    foreach ($lockedName in $Lock.dependencies.Keys) {
        if (-not $seen.ContainsKey($lockedName)) {
            $null = $problems.Add("[$lockedName] is in the lock but not in the DependencyFile")
        }
    }
    if ($problems.Count -gt 0) {
        $message = "Lock file [$LockPath] is out of date with [$DependencyFile]:`n - $($problems -join "`n - ")"
        $message += "`nRun Update-PSDependLock -Path '$DependencyFile' to refresh it, or use -IgnoreLock to resolve without it"
        throw $message
    }


    $synthesized = [ordered]@{}
    $usedDependencyNames = @{}
    foreach ($root in $Dependency) {
        $usedDependencyNames[$root.DependencyName] = $true
    }

    function New-LockedDependencyName {
        param([string]$Name, [string]$Version, [string]$ContextName)

        $baseName = "$Name@$Version"
        $candidate = $baseName
        if ($usedDependencyNames.ContainsKey($candidate)) {
            $candidate = "$baseName#$ContextName"
        }
        $suffix = 2
        while ($usedDependencyNames.ContainsKey($candidate)) {
            $candidate = "$baseName#$ContextName-$suffix"
            $suffix++
        }
        $usedDependencyNames[$candidate] = $true
        $candidate
    }

    function Get-LockedPackage {
        param([string]$Key)
        if (-not $Lock.packages.Contains($Key)) {
            throw "Lock file [$LockPath] is corrupt: package [$Key] is referenced but not locked. Run Update-PSDependLock -Path '$dependencyFile' to regenerate it."
        }
        $Lock.packages[$Key]
    }

    # Materialization is scoped to a root Dependency. The same locked package
    # may need installing more than once when roots use different Targets,
    # Sources, Parameters or Tags.
    function Resolve-LockedChild {
        param(
            [string]$Key,
            [PSObject]$Template,
            [string]$RootKey,
            [string]$ContextName
        )

        if ($Key -eq $RootKey) {
            return $Template.DependencyName
        }
        $materializationKey = "$ContextName`0$Key"
        if ($synthesized.Contains($materializationKey)) {
            return $synthesized[$materializationKey].DependencyName
        }
        $package = Get-LockedPackage -Key $Key
        $name = $Key.Substring($Key.IndexOf('::') + 2)
        $child = [PSCustomObject]@{
            PSTypeName      = 'PSDepend.Dependency'
            DependencyFile  = $Template.DependencyFile
            DependencyName  = (New-LockedDependencyName -Name $name -Version $package.version -ContextName $ContextName)
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
        # Register before recursion so a cycle terminates at the existing node.
        $synthesized[$materializationKey] = $child
        $child.DependsOn = Get-LockedChildList -Package $package -DependencyType $Template.DependencyType `
            -Template $Template -RootKey $RootKey -ContextName $ContextName
        $child.DependencyName
    }

    function Get-LockedChildList {
        param(
            $Package,
            [string]$DependencyType,
            [PSObject]$Template,
            [string]$RootKey,
            [string]$ContextName
        )

        $names = foreach ($childName in $Package.dependencies.Keys) {
            Resolve-LockedChild -Key "${DependencyType}::$childName" -Template $Template `
                -RootKey $RootKey -ContextName $ContextName
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
        $children = Get-LockedChildList -Package $package -DependencyType $root.DependencyType `
            -Template $root -RootKey $entry.resolved -ContextName $root.DependencyName
        if ($children) {
            $dependencies = @($root.DependsOn) + $children
            $root.DependsOn = @($dependencies | Where-Object { $_ } | Select-Object -Unique)
        }
    }

    $Dependency
    $synthesized.Values
}
