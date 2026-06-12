# This installs the .NET SDK that satisfies the Channel, Version, and InstallDir that is passed in
# If on Windows, it will download the .NET SDK PowerShell install script (dotnet-install.ps1)
# On all other platforms, it will download the .NET SDK shell script (dotnet-install.sh)
function Install-Dotnet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Channel,

        [Parameter(Mandatory = $true)]
        [string]
        $Version,

        [Parameter(Mandatory = $true)]
        [string]
        $InstallDir
    )

    $IsWindowsEnv = !$PSVersionTable.Platform -or $PSVersionTable.Platform -eq "Win32NT"

    $obtainUrl = "https://raw.githubusercontent.com/dotnet/cli/main/scripts/obtain"

    try {
        # remove the old folder, download, and run the dotnet-install script for the correct platform
        Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
        $installScript = if ($IsWindowsEnv) { "dotnet-install.ps1" } else { "dotnet-install.sh" }
        Invoke-WebRequest -Uri $obtainUrl/$installScript -OutFile $installScript

        if ($IsWindowsEnv) {
            & .\$installScript -Channel $Channel -Version $Version -InstallDir $InstallDir
        }
        else {
            bash ./$installScript -c $Channel -v $Version --install-dir $InstallDir
        }
    }
    finally {
        # delete the downloaded install script
        Remove-Item $installScript -Force -ErrorAction SilentlyContinue
    }
}
