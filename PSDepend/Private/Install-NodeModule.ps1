functionInstall-NodeModule {
    [CmdletBinding()]
    Param(
        [string]$Version,
        [switch]$Global,
        [string]$PackageName
    )
    npm install --silent $(If ($Global -eq $true) { '--global' }) $PackageName$(If(![string]::IsNullOrEmpty($Version)){"@$Version"})
}
