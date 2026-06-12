Function Get-TaggedDependency {
    param(
        [object[]]$Dependency,
        [string[]]$Tags
    )

    # Only return dependency with all specified tags
    foreach ($Depend in $Dependency) {
        $Include = $False
        foreach ($Tag in @($Tags)) {
            if ($Depend.Tags -contains $Tag) {
                $Include = $True
            }
        }
        If ($Include) {
            $Depend
        }
    }
}
