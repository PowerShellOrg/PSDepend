# This tests if if the .NET SDK of the specified version exists
# If you specify the InstallDir, it will check if the .NET SDK exists there
# Otherwise it will use the global .NET SDK location.
function Test-Dotnet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Version,
        
        [Parameter()]
        [string]
        $InstallDir
    )

    $IsWindowsEnv = !$PSVersionTable.Platform -or $PSVersionTable.Platform -eq "Win32NT"
    $dotnetFile = if ($IsWindowsEnv) { "dotnet.exe" } else { "dotnet" }

    if ($InstallDir) {
        $dotnetExePath = Join-Path -Path $InstallDir -ChildPath $dotnetFile
    }
    else {
        # If dotnet is already in the PATH, check to see if that version of dotnet can find the required SDK.
        # This is "typically" the globally installed dotnet.
        $dotnetInPath = Get-Command 'dotnet' -ErrorAction SilentlyContinue
        if ($dotnetInPath) {
            $dotnetExePath = $dotnetInPath.Source
        }
        else {
            $LocalDotnetDirPath = if ($IsWindowsEnv) { "$env:LocalAppData\Microsoft\dotnet" } else { "$env:HOME/.dotnet" }
            $dotnetExePath = Join-Path -Path $LocalDotnetDirPath -ChildPath $dotnetFile
        }
    }
    
    if (Test-Path $dotnetExePath) {
        $installedVersion = Get-DotnetVersion $dotnetExePath
        if ($Version -eq 'latest') {
            # TODO: This could query the version if you have the latest
            return $false
        }
        else {
            # We need to separate the prerelease from the version
            $installedVer, $installedPre = ($installedVersion -split '-')
            $ver, $pre = ($Version -split '-')

            if ([version] $installedVer -gt [version] $ver) { return $true }
            if ([version] $installedVer -lt [version] $ver) { return $false }

            # Handle the case if they have the same version but no prerelease
            if ($installedPre -eq "") { return $true }
            if ($pre -eq "") { return $false }

            # Compare prerelease if they both have them
            return $installedPre -ge $pre
        }
    }
    return $false
}

# Pulled out for mocking purpose
function Get-DotnetVersion {
    param(
        [string]
        $dotnetExePath
    )

    & $dotnetExePath --version
}
