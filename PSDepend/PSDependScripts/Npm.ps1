<#
    .SYNOPSIS
        Install a node package from NPM.

    .DESCRIPTION
        Install a node package from NPM.

        Note: We require npm in your path.

        Relevant Dependency metadata:
            DependencyName (Key): Node Package Name
            Version: Version of the node package to install; defaults to latest.
            Target: Path to place the node_modules folder, and all relevant packages, in.
                    You can specify a full path, a UNC path, or a relative path from the
                    current directory. You can also specify the special keyword, 'Global',
                    which will cause the node package to be installed globally for the
                    user who runs PSDepend against this dependency.

    .PARAMETER Dependency
        Dependency to process

    .PARAMETER Global
        If specified, the node package will be installed globally.

    .PARAMETER PSDependAction
        Test or Install the dependency.  Defaults to Install

        Test: Return true or false on whether the dependency is in place
        Install: Install the dependency

    .EXAMPLE
        @{
            'gitbook-cli' = @{
                DependencyType = 'Npm'
                Version        = '0.1.0'
                Target         = 'Global'
            }
        }

        # Full syntax
            # DependencyName (key) uses (unique) name 'gitbook-cli'
            # Specify a version to install
            # Ensure the package is installed globally.

    .EXAMPLE
        @{
            'gitbook-cli' = @{
                DependencyType = 'Npm'
            }
        }

        # Simple syntax
            # The example package, 'gitbook-cli' will be installed
            at the latest version from NPM to the current directory.

#>
[CmdletBinding()]
param (
    [PSTypeName('PSDepend.Dependency')]
    [PSObject[]]$Dependency,

    [ValidateSet('Test', 'Install')]
    [string[]]$PSDependAction = @('Install'),
    [switch]$Force,
    [switch]$Global
)
#region    Extract Dependency Data
$Name = $Dependency.DependencyName
$Version = $Dependency.Version
$Target = $Dependency.Target
If (-not [string]::IsNullOrEmpty($Target) -and $Target -ne 'global') {
    # If the target matches a full path or UNC path, don't modify it;
    # Otherwise, assume that its a folder _in the current directory_.
    # If no target is specified, it will install to the current directory.
    If ($Target -notmatch '(^/|:|\\\\)') {
        $Target = Join-Path $PWD $Target
    }
    If (-not (Test-Path $Target) -and $PSDependAction -contains 'Install') {
        Write-Verbose "Creating folder [$Target] for node module dependency [$Name]"
        $null = New-Item -ItemType directory -Path  $Target -Force
    }
}
#endregion Extract Dependency Data
#region    Test Action
If ($PSDependAction -contains 'Test') {
    If ([string]::IsNullOrEmpty($Target)) {
        $InstalledNodeModules = Get-NodeModule
    }
    ElseIf ($Target -eq 'global') {
        $InstalledNodeModules = Get-NodeModule -Global
    }
    Else {
        Push-Location $Target
        $InstalledNodeModules = Get-NodeModule
        Pop-Location
    }
    $InstalledModule = $InstalledNodeModules.$Name
    If ($null -eq $InstalledModule) {
        return $false
    }
    ElseIf ($null -ne $Version -and $InstalledModule.Version -ne $Version) {
        return $false
    }
    Else {
        return $true
    }
}
#endregion Test Action
#region    Install Action
If ($PSDependAction -contains 'Install') {
    If ([string]::IsNullOrEmpty($Target)) {
        $null = Install-NodeModule -PackageName $Name -Version $Version
    }
    ElseIf ($Target -eq 'global') {
        $null = Install-NodeModule -PackageName $Name -Version $Version -Global
    }
    Else {
        Push-Location $Target
        $null = Install-NodeModule -PackageName $Name -Version $Version
        Pop-Location
    }
}
#endregion Install Action
