<#
    .SYNOPSIS
        Installs the .NET Core SDK.

    .DESCRIPTION
        Installs the .NET Core SDK.

        Relevant Dependency metadata:
            DependencyName (Key): The .NET Core SDK download channel - ex. release, LTS, etc.
            Version: Minimum version you need on your system.
            Target: Path to place the .dotnet folder, which contains the .NET Core SDK.
                    You can specify a full path, a UNC path, or a relative path from the
                    current directory. You can also specify the special keyword, 'Global',
                    which will cause the node package to be installed globally for the
                    user who runs PSDepend against this dependency.

    .PARAMETER Dependency
        Dependency to process

    .PARAMETER PSDependAction
        Test, Install, or Import the dependency.  Defaults to Install

        Test: Return true or false on whether the dependency is in place
        Install: Install the dependency
        Import: Adds the .NET Core SDK to $env:PATH

    .EXAMPLE
        @{
            'release' = @{
                DependencyType = 'DotnetSdk'
                Version        = '2.1.0'
                Target         = './.dotnet/'
            }
        }

        # Full syntax
            # DependencyName (key) uses (unique) channel name 'release'
            # Specify a version to install
            # Ensure the package is installed locally in a .dotnet folder.

    .EXAMPLE
        @{
            'DotnetSdk::LTS' = 'latest'
        }

        # Simple syntax
        # The .NET SDK will be installed with the latest version from the LTS channel, globally.

#>
[CmdletBinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [PSObject[]]
    $Dependency,

    [ValidateSet('Test', 'Install', 'Import')]
    [string[]]
    $PSDependAction = @('Install')
)

# Users can specify 'Global which will use the default global path of
# "$env:LocalAppData\Microsoft\dotnet" on Windows or "$env:HOME/.dotnet" elsewhere
# Since Global is the default behavior, we ignore the fact that the Target was set.
$InstallDir = if ($Dependency.Target -and $Dependency.Target -ne 'Global') { $Dependency.Target }
$Version = $Dependency.Version
$Channel = if ($Dependency.DependencyName) { $Dependency.DependencyName } else { "release" }

# The 'global' install location is different per platform
$IsWindowsEnv = !$PSVersionTable.Platform -or $PSVersionTable.Platform -eq "Win32NT"
$globalDotnetSdkLocation = if ($IsWindowsEnv) { "$env:LocalAppData\Microsoft\dotnet" } else { "$env:HOME/.dotnet" }

# Handle 'Test'
if ($PSDependAction -contains 'Test') {
    # Returns true if the .NET Core SDK can be found
    return Test-Dotnet -Version $Version -InstallDir $InstallDir
}

# Handle 'Install'
if ($PSDependAction -contains 'Install') {
    if (!(Test-Dotnet -Version $Version -InstallDir $InstallDir)) {
        # If the InstallDir is not set, set it to the 'global' path
        if (!$InstallDir) {
            $InstallTo = $globalDotnetSdkLocation
        }
        else {
            $InstallTo = $InstallDir
        }
        Install-Dotnet -Channel $Channel -Version $Version -InstallDir $InstallTo
    }
}

# Handle 'Import'
if ($PSDependAction -contains 'Import') {
    # If the InstallDir was specified and the .NET Core SDK exists in it, add it to the path
    if ($InstallDir -and (Test-Dotnet -Version $Version -InstallDir $InstallDir)) {
        $env:PATH = "$InstallDir$([IO.Path]::PathSeparator)$env:PATH"
    }
    else {
        # Test if it's in the path already and if it's not check if it's in the 'global' location
        $dotnetInPath = Get-Command 'dotnet' -ErrorAction SilentlyContinue
        if (!$dotnetInPath) {
            if (!(Test-Dotnet -Version $Version -InstallDir $globalDotnetSdkLocation)) {
                throw ".NET SDK cannot be located. Try installing using PSDepend."
            }
            else {
                $env:PATH = "$globalDotnetSdkLocation$([IO.Path]::PathSeparator)$env:PATH"
            }
        }
    }
}
