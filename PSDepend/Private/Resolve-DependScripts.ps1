# Borrowed from Pester and stripped down
# This might be overkill
function Resolve-DependScripts {
    param ([object[]] $Path, [bool]$Recurse = $True)
    $resolvedScriptInfo = @(
        foreach ($object in $Path) {
            $unresolvedPath = [string] $object
            if ($unresolvedPath -notmatch '[\*\?\[\]]' -and
                (Test-Path -LiteralPath $unresolvedPath -PathType Leaf) -and
                (Get-Item -LiteralPath $unresolvedPath -Force) -is [System.IO.FileInfo]) {
                $extension = [System.IO.Path]::GetExtension($unresolvedPath)
                if ($extension -ne '.psd1') {
                    Write-Error "Script path '$unresolvedPath' is not a psd1 file."
                }
                else {
                    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($unresolvedPath)
                }
            }
            else {
                $RecurseParam = @{Recurse = $False }
                if ($Recurse) {
                    $RecurseParam.Recurse = $True
                }
                Resolve-Path -Path $unresolvedPath |
                    Where-Object { $_.Provider.Name -eq 'FileSystem' } |
                    Select-Object -ExpandProperty ProviderPath |
                    Get-ChildItem -Force -Filter *.psd1 @RecurseParam |
                    Where-Object { -not $_.PSIsContainer -and $_.Name -match '\.depend\.psd1$|.*requirements.psd1$' } |
                    Select-Object -ExpandProperty FullName -Unique
            }
        }
    )
    $resolvedScriptInfo | Select-Object -Unique
}
