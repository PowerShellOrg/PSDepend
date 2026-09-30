function Resolve-PSDependLock {
    <#
    .SYNOPSIS
    Resolve the full dependency graph of one DependencyFile into a lock object.

    .DESCRIPTION
    Walks every Dependency whose DependencyType supports the Resolve
    PSDependAction, asking the DependencyScript for the highest version that
    satisfies the current constraints and for that version's own dependencies.
    Children are queued with their constraints; a package that is required by
    several parents is resolved once against the intersection of all their
    constraints (Join-VersionRange), so the lock holds exactly one version per
    DependencyType::Name. When a parent is re-resolved its previous child
    constraints are dropped and the loop continues until no node violates a
    constraint (a fixpoint), then unreachable nodes are pruned.

    Dependencies whose DependencyType cannot Resolve (or is unsupported on this
    platform) are recorded without a resolved package so a later run can still
    detect when the DependencyFile changed.

    Returns an ordered hashtable with lockfileVersion, dependencies (one entry
    per DependencyName in the file) and packages (one entry per resolved
    DependencyType::Name). Throws on unresolvable or conflicting constraints.

    .PARAMETER Dependency
    The Dependencies of one DependencyFile, as returned by Get-Dependency -IgnoreLock.

    .PARAMETER PSDependTypePath
    PSDependMap.psd1 mapping DependencyTypes to their scripts.

    .EXAMPLE
    Resolve-PSDependLock -Dependency (Get-Dependency -Path .\requirements.psd1 -IgnoreLock)

    Returns the lock object for requirements.psd1.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [PSTypeName('PSDepend.Dependency')]
        [PSObject[]]$Dependency,

        [string]$PSDependTypePath = $(Join-Path $ModuleRoot PSDependMap.psd1)
    )

    $maxIterations = 10000

    $types = Get-PSDependType -Path $PSDependTypePath -SkipHelp
    $scripts = Get-PSDependScript -Path $PSDependTypePath
    $resolvable = @{}
    function Test-Resolvable {
        param([string]$DependencyType)
        if (-not $resolvable.ContainsKey($DependencyType)) {
            $type = $types | Where-Object { $_.DependencyType -eq $DependencyType }
            $supported = $false
            if ($type -and $type.Supported -and $scripts.$DependencyType) {
                $actions = Get-Parameter -Command $scripts.$DependencyType |
                    Where-Object { $_.Name -eq 'PSDependAction' } |
                    Select-Object -ExpandProperty ValidateSetValues -ErrorAction SilentlyContinue
                $supported = $actions -contains 'Resolve'
            }
            if (-not $supported) {
                Write-Verbose "DependencyType [$DependencyType] does not support Resolve on this platform; it will not be locked"
            }
            $resolvable[$DependencyType] = $supported
        }
        $resolvable[$DependencyType]
    }

    function Get-Requested {
        param($Version)
        if ([string]::IsNullOrEmpty($Version)) { 'latest' } else { [string]$Version }
    }

    $roots = [ordered]@{}
    $nodes = @{}        # key -> @{ Name; DependencyType; Version; Dependencies; Template; Constraints = @{ source -> range } }
    $queue = New-Object System.Collections.Generic.Queue[string]

    foreach ($root in $Dependency) {
        $name = if ($root.Name) { $root.Name } else { $root.DependencyName }
        $requested = Get-Requested $root.Version
        $entry = [ordered]@{
            dependencyType = $root.DependencyType
            name           = $name
            requested      = $requested
        }
        if (Test-Resolvable -DependencyType $root.DependencyType) {
            $key = "$($root.DependencyType)::$name"
            $entry.resolved = $key
            if (-not $nodes.ContainsKey($key)) {
                $nodes[$key] = @{
                    Name           = $name
                    DependencyType = $root.DependencyType
                    Version        = $null
                    Dependencies   = @{}
                    Template       = $root
                    Constraints    = @{}
                }
            }
            $nodes[$key].Constraints["root:$($root.DependencyName)"] = $requested
            $queue.Enqueue($key)
        }
        $roots[$root.DependencyName] = $entry
    }

    $iterations = 0
    while ($queue.Count -gt 0) {
        if (++$iterations -gt $maxIterations) {
            throw "Dependency resolution did not converge after [$maxIterations] steps; the dependency graph is probably cyclic with conflicting constraints"
        }
        $key = $queue.Dequeue()
        $node = $nodes[$key]
        $constraints = @($node.Constraints.Values)

        # A single constraint is passed through verbatim so DependencyTypes with
        # their own range syntax (npm semver) still work; several are intersected.
        if ($constraints.Count -eq 1) {
            $combined = $constraints[0]
        } else {
            $combined = Join-VersionRange -Range $constraints -ErrorAction SilentlyContinue -ErrorVariable joinError
            if (-not $combined) {
                $required = ($node.Constraints.GetEnumerator() | ForEach-Object { "$($_.Key) requires [$($_.Value)]" }) -join '; '
                throw "Cannot lock [$key]: $($joinError[0]). $required"
            }
        }

        if ($node.Version) {
            $satisfied = if ($combined -eq 'latest') { $true } else { Test-VersionInRange -Version $node.Version -Required $combined }
            if ($satisfied) {
                continue
            }
            Write-Verbose "Re-resolving [$key]: version [$($node.Version)] no longer satisfies [$combined]"
        }

        $template = $node.Template
        $probe = [PSCustomObject]@{
            PSTypeName      = 'PSDepend.Dependency'
            DependencyFile  = $template.DependencyFile
            DependencyName  = $node.Name
            DependencyType  = $node.DependencyType
            Name            = $node.Name
            Version         = $combined
            Parameters      = $template.Parameters
            Source          = $template.Source
            Target          = $template.Target
            AddToPath       = $false
            Tags            = $template.Tags
            DependsOn       = $null
            PreScripts      = $null
            PostScripts     = $null
            Credential      = $template.Credential
            PSDependOptions = $template.PSDependOptions
            Raw             = $null
        }

        Write-Verbose "Resolving [$key] with constraint [$combined]"
        try {
            $resolved = @(Invoke-DependencyScript -Dependency $probe -PSDependAction Resolve -PSDependTypePath $PSDependTypePath -ErrorAction Stop)
        } catch {
            throw "Cannot lock [$key] with constraint [$combined]: $_"
        }
        $resolved = @($resolved | Where-Object { $_.PSObject.TypeNames -contains 'PSDepend.ResolvedDependency' })
        if ($resolved.Count -ne 1 -or [string]::IsNullOrEmpty($resolved[0].Version)) {
            throw "Cannot lock [$key] with constraint [$combined]: the [$($node.DependencyType)] DependencyScript did not return a resolved version"
        }
        $result = $resolved[0]

        # Drop the constraints this node imposed on its previous children
        foreach ($childKey in @($nodes.Keys)) {
            $null = $nodes[$childKey].Constraints.Remove("node:$key")
        }

        $node.Version = [string]$result.Version
        $node.Dependencies = @{}
        if ($result.Dependencies) {
            foreach ($childName in $result.Dependencies.Keys) {
                $node.Dependencies[$childName] = Get-Requested $result.Dependencies[$childName]
            }
        }
        Write-Verbose "Locked [$key] at [$($node.Version)] with [$($node.Dependencies.Count)] dependencies"

        foreach ($childName in $node.Dependencies.Keys) {
            $childKey = "$($node.DependencyType)::$childName"
            if (-not $nodes.ContainsKey($childKey)) {
                $nodes[$childKey] = @{
                    Name           = $childName
                    DependencyType = $node.DependencyType
                    Version        = $null
                    Dependencies   = @{}
                    Template       = $template
                    Constraints    = @{}
                }
            }
            $nodes[$childKey].Constraints["node:$key"] = $node.Dependencies[$childName]
            $queue.Enqueue($childKey)
        }
    }

    # Keep only packages still reachable from the DependencyFile
    $reachable = @{}
    $walk = New-Object System.Collections.Generic.Queue[string]
    foreach ($entry in $roots.Values) {
        if ($entry.Contains('resolved')) { $walk.Enqueue($entry.resolved) }
    }
    while ($walk.Count -gt 0) {
        $key = $walk.Dequeue()
        if ($reachable.ContainsKey($key)) { continue }
        $reachable[$key] = $true
        foreach ($childName in $nodes[$key].Dependencies.Keys) {
            $walk.Enqueue("$($nodes[$key].DependencyType)::$childName")
        }
    }

    $packages = [ordered]@{}
    foreach ($key in ($reachable.Keys | Sort-Object)) {
        $node = $nodes[$key]
        $dependencies = [ordered]@{}
        foreach ($childName in ($node.Dependencies.Keys | Sort-Object)) {
            $dependencies[$childName] = $node.Dependencies[$childName]
        }
        $packages[$key] = [ordered]@{
            version      = $node.Version
            dependencies = $dependencies
        }
    }

    [ordered]@{
        lockfileVersion = 1
        dependencies    = $roots
        packages        = $packages
    }
}
