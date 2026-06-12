function Add-ToPsModulePathIfRequired {
    [cmdletbinding()]
    param(
        [PSTypeName('PSDepend.Dependency')]
        [psobject]$Dependency,
        [string[]]$Action
    )

    process {
        $path = $Dependency.Target
        if ([string]::IsNullOrWhiteSpace($path) -or -not($Dependency.AddToPath)) {
            return
        }
        if ('AllUsers', 'CurrentUser' -contains $path) {
            return
        }
        $isInstallOrImport = @($Action | Where-Object { $_ -In 'Install', 'Import' }).Count -gt 0
        if (-not $isInstallOrImport) {
            return
        }

        if ($Action -contains 'Install' -and -not(Test-Path $path -PathType Container)) {
            Write-Verbose "Creating directory path to [$path]"
            $Null = New-Item -ItemType Directory -Path $path -Force -ErrorAction SilentlyContinue
        }

        Write-Verbose "Setting PSModulePath to`n$($path, $env:PSModulePath -join ';' | Out-String)"
        Add-ToItemCollection -Reference Env:\PSModulePath -Item (Get-Item $path -Force).FullName
    }
}
