<#
    .SYNOPSIS
        Installs a package from a Nuget repository like Nuget.org using nuget.exe

    .DESCRIPTION
        Installs a package from a Nuget repository like Nuget.org using nuget.exe

        Relevant Dependency metadata:
            Name: The name of the package
            Version: Used to identify existing installs meeting this criteria.  Defaults to 'latest'
            Source: Source Uri for Nuget.  Defaults to https://www.nuget.org/api/v2/
            Target: Required path to save this module.  No Default
                Example: To install PSDeploy to C:\temp\PSDeploy, I would specify C:\temp

    .PARAMETER Force
        If specified and Target already exists, remove existing item before saving

    .PARAMETER PSDependAction
        Test, or Install the package.  Defaults to Install

        Test: Return true or false on whether the dependency is in place
        Install: Install the dependency

    .EXAMPLE

        @{
            'Newtonsoft.Json' = @{
                DependencyType = 'Nuget'
                Target = 'C:\Temp'
                Version = '12.0.2'
            }
        }

        # Install Newtonsoft.Json via Nuget.org, to C:\temp, at version 12.0.2

    .EXAMPLE

        @{
            'MyCompany.Models' = @{
                DependencyType = 'Nuget'
                Source = 'https://nuget.int.feed/'
                Target = 'C:\Temp'
            }
        }

        # Install the latest version of MyCompany.Models on an internal nuget feed, to C:\temp

    .EXAMPLE

        @{
            PSDependOptions = @{
                DependencyType = 'Nuget'
                Target = ".\Staging"
            }
            'Portable.BouncyCastle' = @{
                Version = 'latest'
                Parameters = @{
                    Name = 'BouncyCastle.Crypto'
                }
            }
            'MimeKit' = 'latest'
            'Newtonsoft.Json' = 'latest'
        }

        # Installs the list of Nuget packages from Nuget.org using the Global PSDependOptions to limit repetition. Packages will be downloaded to the Staging directory in the current working directory. Since the DLL included with Portable.BouncyCastle is actually named 'BouncyCastle.Crypto', we specify that in the parameters.

#>
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [switch]$Force,

    [ValidateSet('Test', 'Install')]
    [string[]]$PSDependAction = @('Install'),

    [Alias('DLLName')]
    [string]$Name
)
# Extract data from Dependency
    $DependencyName = $Dependency.DependencyName
    if ($null -ne $Dependency.Name)
    {
        $DependencyName = $Dependency.Name
    }

    $Version = $Dependency.Version
    if(-not $Version)
    {
        $Version = 'latest'
    }

    $Source = $Dependency.Source
    if(-not $Dependency.Source)
    {
        $Source = 'https://www.nuget.org/api/v2/'
    }

    # We use target as a proxy for Scope
    $Target = $Dependency.Target
    if(-not $Dependency.Target)
    {
        Write-Error "Nuget requires a Dependency Target. Skipping [$DependencyName]"
        return
	}

	$Credential = $Dependency.Credential

if(-not (Get-Command Nuget -ErrorAction SilentlyContinue))
{
    Write-Error "Nuget requires Nuget.exe.  Ensure this is in your path, or explicitly specified in $ModuleRoot\PSDepend.Config's NugetPath.  Skipping [$DependencyName]"
}

Write-Verbose -Message "Getting dependency [$DependencyName] from Nuget source [$Source]"

# This code works for both install and save scenarios.
$PackagePath =  Join-Path $Target $DependencyName

$NameIs = if ($PSBoundParameters.ContainsKey('Name')) {
    $Name
}
else {
    $DependencyName
}

if(Test-Path $PackagePath)
{
    if($null -eq (Get-ChildItem $PackagePath -Filter "$NameIs*" -Include '*.exe', '*.dll' -Recurse))
    {
        # For now, skip if we don't find a DLL matching the expected name
        Write-Error "Could not find existing DLL for dependency [$DependencyName] in package path [$PackagePath]"
        return
    }

    Write-Verbose "Found existing package [$DependencyName]"

    # Thanks to Brandon Padgett!
    $Path = (Get-ChildItem $PackagePath -Filter "$NameIs*" -Include '*.exe', '*.dll' -Recurse | Select-Object -First 1).FullName
    $ExistingVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($Path).FileVersion
    $GetGalleryVersion = { (Find-NugetPackage -Name $DependencyName -PackageSourceUrl $Source -Credential $Credential -IsLatest).Version }

    # Version string, and equal to current
    if( $Version -and $Version -ne 'latest' -and $Version -eq $ExistingVersion)
    {
        Write-Verbose "You have the requested version [$Version] of [$DependencyName]"
        if($PSDependAction -contains 'Test')
        {
            return $True
        }
        return $null
    }

    # latest, and we have latest
    if( $Version -and
        ($Version -eq 'latest' -or $Version -like '') -and
        ($GalleryVersion = [System.Version](& $GetGalleryVersion)) -le [System.Version]$ExistingVersion
    )
    {
        Write-Verbose "You have the latest version of [$DependencyName], with installed version [$ExistingVersion] and Source version [$GalleryVersion]"
        if($PSDependAction -contains 'Test')
        {
            return $True
        }
        return $null
    }

    Write-Verbose "Removing existing [$PackagePath]`nContinuing to install [$DependencyName]: Requested version [$version], existing version [$ExistingVersion]"
    if($PSDependAction -contains 'Install')
    {
        if($Force)
        {
            Remove-Item $PackagePath -Force -Recurse
        }
        else
        {
            Write-Verbose "Use -Force to remove existing [$PackagePath]`nSkipping install of [$DependencyName]: Requested version [$version], existing version [$ExistingVersion]"
            if( $PSDependAction -contains 'Test')
            {
                return $false
            }
            return $null
        }
    }
}

#No dependency found, return false if we're testing alone...
if( $PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1)
{
    return $False
}

if($PSDependAction -contains 'Install')
{
    $TargetExists = Test-Path $Target -PathType Container

    Write-Verbose "Saving [$DependencyName] with path [$Target]"
    $NugetParams = '-Source', $Source, '-ExcludeVersion', '-NonInteractive', '-OutputDirectory', $Target
    if(-not $TargetExists)
    {
        Write-Verbose "Creating directory path to [$Target]"
        $Null = New-Item -ItemType Directory -Path $Target -Force -ErrorAction SilentlyContinue
    }
    if($Version -and $Version -notlike 'latest')
    {
        $NugetParams += '-version', $Version
    }
    $NugetParams = 'install', $DependencyName + $NugetParams

	Invoke-ExternalCommand Nuget -Arguments $NugetParams
}
