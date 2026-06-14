function Validate-DependencyParameters {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string[]]$Required,
        [string[]]$Parameters
    )
    foreach ($RequiredParam in $Required) {
        if ($Parameters -notcontains $RequiredParam) {
            return $false
        }
    }
    $true
}
