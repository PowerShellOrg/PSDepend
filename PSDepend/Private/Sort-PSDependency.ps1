function Sort-PSDependency {
    [cmdletbinding()]
    [OutputType([object[]])]
    param(
        [object[]]$Dependencies
    )

    $Order = @{}
    Foreach ($Dependency in $Dependencies) {
        if ($Dependency.DependsOn) {
            if (-not $Order.ContainsKey($Dependency.DependencyName)) {
                $Order.add($Dependency.DependencyName, $Dependency.DependsOn)
            }
        }
    }

    if ($Order.Keys.Count -gt 0) {
        $DependencyOrder = Get-TopologicalSort $Order
        Sort-ObjectWithCustomList -InputObject $Dependencies -Property DependencyName -CustomList $DependencyOrder
    }
    else {
        $Dependencies
    }
}
