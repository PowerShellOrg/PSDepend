# All credit and major props to Joel Bennett for this simplified solution that doesn't depend on PowerShellGet
# https://gist.github.com/Jaykul/1caf0d6d26380509b04cf4ecef807355
function Save-NugetPackage {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipelineByPropertyName, Mandatory)]$Name,
        [Parameter(ValueFromPipelineByPropertyName, Mandatory)]$Uri,
        [Parameter(ValueFromPipelineByPropertyName)]$Version = "",
        [string]$Path = $pwd
    )
    $Path = (Join-Path $Path "$Name.$Version.nupkg")
    Invoke-WebRequest $Uri -OutFile $Path
    Get-Item $Path
}
