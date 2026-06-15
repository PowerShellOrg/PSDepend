<#
    .SYNOPSIS
        Installs a module from a PowerShell repository like the PowerShell Gallery using nuget.exe

    .DESCRIPTION
        Installs a module from a PowerShell repository like the PowerShell Gallery using nuget.exe

        Note: If we find an existing module that doesn't meet the specified criteria in the Target, we remove it.

        Relevant Dependency metadata:
            Name: The name for this module
            Version: Used to identify existing installs meeting this criteria, and as RequiredVersion for installation.  Defaults to 'latest'
                Also accepts a NuGet version range (e.g. '[2.2.3,3.0)', '[2.0,)', '(,3.0)').  A bare version (e.g. '0.1.19') still means that exact version.  When a range is given, the highest available version that satisfies it is installed.
            Source: Source Uri for Nuget.  Defaults to https://www.powershellgallery.com/api/v2/
            Target: Required path to save this module.  No Default
                Example: To install PSDeploy to C:\temp\PSDeploy, I would specify C:\temp
            AddToPath: Prepend the Target to ENV:PSModulePath

    .PARAMETER Force
        If specified and Target already exists, remove existing item before saving

    .PARAMETER Import
        If specified, import the module in the global scope

    .PARAMETER PSDependAction
        Test, Install, or Import the module.  Defaults to Install

        Test: Return true or false on whether the dependency is in place
        Install: Install the dependency
        Import: Import the dependency

    .EXAMPLE

        @{
            PSDeploy = @{
                DependencyType = 'PSGalleryNuget'
                Target = 'C:\Temp'
                Version = '0.1.19'
            }
        }

        # Install PSDeploy via nuget PSGallery feed, to C:\temp, at version 0.1.19

    .EXAMPLE

        @{
            PSDeploy = @{
                DependencyType = 'PSGalleryNuget'
                Source = 'https://nuget.int.feed/'
                Target = 'C:\Temp'
            }
        }

        # Install the latest version of PSDeploy on an internal nuget feed, to C:\temp,

#>
[CmdletBinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [PSObject[]]$Dependency,

    [switch]$Force,

    [switch]$Import,

    [ValidateSet('Test', 'Install', 'Import')]
    [string[]]$PSDependAction = @('Install')
)
# Extract data from Dependency
$DependencyName = $Dependency.DependencyName
$Name = $Dependency.Name
if (-not $Name) {
    $Name = $DependencyName
}

$Version = $Dependency.Version
if (-not $Version) {
    $Version = 'latest'
}

$Source = $Dependency.Source
if (-not $Dependency.Source) {
    $Source = 'https://www.powershellgallery.com/api/v2/'
}

# We use target as a proxy for Scope
$Target = $Dependency.Target
if (-not $Dependency.Target) {
    Write-Error "PSGalleryNuget requires a Dependency Target. Skipping [$DependencyName]"
    return
}

$Credential = $Dependency.Credential

if (-not (Get-Command Nuget -ErrorAction SilentlyContinue)) {
    if (Test-PlatformSupport -Type 'PSGalleryNuget' -Support 'windows', 'core') {
        BootStrap-Nuget -NugetPath $NuGetPath
    }
    if (-not (Get-Command Nuget -ErrorAction SilentlyContinue)) {
        Write-Error "PSGalleryNuget requires Nuget.exe.  Ensure this is in your path, or explicitly specified in $ModuleRoot\PSDepend.Config's NugetPath.  Skipping [$DependencyName]"
        return
    }
}

Write-Verbose -Message "Getting dependency [$name] from Nuget source [$Source]"

# This code works for both install and save scenarios.
$ModulePath = Join-Path $Target $Name

Add-ToPsModulePathIfRequired -Dependency $Dependency -Action $PSDependAction

if (Test-Path $ModulePath) {
    $Manifest = Join-Path $ModulePath "$Name.psd1"
    if (-not (Test-Path $Manifest)) {
        # For now, skip if we don't find a psd1
        Write-Error "Could not find manifest [$Manifest] for dependency [$Name]"
        return
    }

    Write-Verbose "Found existing module [$Name]"

    # Thanks to Brandon Padgett!
    $ManifestData = Import-LocalizedData -BaseDirectory $ModulePath -FileName "$Name.psd1"
    $ExistingVersion = $ManifestData.ModuleVersion
    $GetGalleryVersion = { (Find-NugetPackage -Name $Name -PackageSourceUrl $Source -Credential $Credential -IsLatest).Version }

    # Version string (exact or range), and the installed version satisfies it
    if ($Version -and $Version -ne 'latest') {
        if (Test-VersionInRange -Version $ExistingVersion -Required $Version) {
            Write-Verbose "You have the requested version [$Version] of [$Name]"
            # Conditional import
            Import-PSDependModule -Name $ModulePath -Action $PSDependAction -Version $ExistingVersion
            if ($PSDependAction -contains 'Test') {
                return $True
            }
            return $null
        }
    }

    # latest, and we have latest
    if ($Version -and ($Version -eq 'latest' -or $Version -like '')) {
        $GalleryVersion = & $GetGalleryVersion
        $isGalleryVersionLessEquals = (Compare-Version -ReferenceVersion ([string]$GalleryVersion) -DifferenceVersion ([string]$ExistingVersion)) -le 0

        if ($isGalleryVersionLessEquals) {
            Write-Verbose "You have the latest version of [$Name], with installed version [$ExistingVersion] and PSGallery version [$GalleryVersion]"
            # Conditional import
            Import-PSDependModule -Name $ModulePath -Action $PSDependAction -Version $ExistingVersion
            if ($PSDependAction -contains 'Test') {
                return $True
            }
            return $null
        }
    }

    Write-Verbose "Removing existing [$ModulePath]`nContinuing to install [$Name]: Requested version [$version], existing version [$ExistingVersion]"
    if ($PSDependAction -contains 'Install') {
        if ($Force) {
            Remove-Item $ModulePath -Force -Recurse
        }
        else {
            Write-Verbose "Use -Force to remove existing [$ModulePath]`nSkipping install of [$Name]: Requested version [$version], existing version [$ExistingVersion]"
            if ( $PSDependAction -contains 'Test') {
                return $false
            }
            return $null
        }
    }
}

#No dependency found, return false if we're testing alone...
if ( $PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1) {
    return $False
}

# Resolve a version range to the highest available version that satisfies it;
# nuget.exe -version takes an exact version, not a range.
$installVersion = $Version
if ($Version -and $Version -notlike 'latest') {
    $range = ConvertFrom-VersionRange -Version $Version
    if ($range -and -not $range.IsExact) {
        $resolvedVersion = $null
        foreach ($candidate in (Find-NugetPackage -Name $Name -PackageSourceUrl $Source -Credential $Credential)) {
            if ((Test-VersionInRange -Version $candidate.Version -Required $Version) -and
                ($null -eq $resolvedVersion -or (Compare-Version -ReferenceVersion $candidate.Version -DifferenceVersion $resolvedVersion) -gt 0)) {
                $resolvedVersion = $candidate.Version
            }
        }
        if (-not $resolvedVersion) {
            Write-Error "No version of [$Name] at source [$Source] satisfies range [$Version]"
            return
        }
        Write-Verbose "Resolved range [$Version] to version [$resolvedVersion] for [$Name]"
        $installVersion = $resolvedVersion
    }
}

if ($PSDependAction -contains 'Install') {
    $TargetExists = Test-Path $Target -PathType Container

    Write-Verbose "Saving [$Name] with path [$Target]"
    $NugetParams = '-Source', $Source, '-ExcludeVersion', '-NonInteractive', '-OutputDirectory', $Target
    if (-not $TargetExists) {
        Write-Verbose "Creating directory path to [$Target]"
        $Null = New-Item -ItemType Directory -Path $Target -Force -ErrorAction SilentlyContinue
    }
    if ($Version -and $Version -notlike 'latest') {
        $NugetParams += '-version', $installVersion
    }
    $NugetParams = 'install', $Name + $NugetParams

    Invoke-ExternalCommand nuget -Arguments $NugetParams
}

# Conditional import
$importVs = if ($Version -and $Version -notlike 'latest') {
    $installVersion
}
Import-PSDependModule -Name $ModulePath -Action $PSDependAction -Version $importVs
