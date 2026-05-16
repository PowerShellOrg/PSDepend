<#
    .SYNOPSIS
        Installs a PowerShell resource from a PowerShell repository using PSResourceGet.

    .DESCRIPTION
        Installs a PowerShell module from a PowerShell repository (such as the PowerShell Gallery)
        using the PSResourceGet module, which replaces the deprecated PowerShellGet module.

        Relevant Dependency metadata:
            Name: The name of the module to install
            Version: Used to identify existing installs meeting this criteria, and as RequiredVersion
                     for installation. Defaults to 'latest'
            Target: Used as 'Scope' for Install-PSResource.
                    If this is a filesystem path, Save-PSResource is used instead.
                    Defaults to 'CurrentUser'
            AddToPath: If Target is used as a path, prepend that path to $ENV:PSModulePath
            Credential: The username and password used to authenticate against a private repository

        This provider relies on PSResourceGet cmdlets such as:
            - Find-PSResource
            - Install-PSResource
            - Save-PSResource

        If PSResourceGet is not available, it must be installed prior to using this provider.

    .PARAMETER Repository
        PSResource repository to download from.
        Defaults to PSGallery.

    .PARAMETER NoClobber
        Allow installation of modules that overwrite existing commands.
        Defaults to $false.

    .PARAMETER AcceptLicense
        Accepts the license agreement during installation.

    .PARAMETER Prerelease
        If specified, allows installation of prerelease versions.

        If specified along with version 'latest', a prerelease will be selected
        if it is the most recent available version.

        Sorting assumes prereleases are named appropriately
        (e.g. alpha < beta < rc).

    .PARAMETER Import
        If specified, imports the module into the global scope.

        Deprecated. Moving to PSDependAction.

    .PARAMETER PSDependAction
        Test, Install, or Import the module.
        Defaults to Install.

        Test:   Returns true or false depending on whether the dependency is present
        Install: Installs the dependency
        Import: Imports the dependency

    .EXAMPLE
        @{
            BuildHelpers = 'latest'
            PSDeploy     = ''
            InvokeBuild  = '3.2.1'
        }

        # From the PSGallery repository...
        # Install the latest BuildHelpers and PSDeploy
        # Install version 3.2.1 of InvokeBuild

    .EXAMPLE
        @{
            BuildHelpers = @{
                Target = 'C:\Build'
            }
        }

        # Install the latest BuildHelpers module from PSGallery to C:\Build
        # (i.e. C:\Build\BuildHelpers will be the module folder)

    .EXAMPLE
        @{
            BuildHelpers = @{
                Parameters = @{
                    Repository = 'PSPrivateGallery'
                    SkipPublisherCheck = $true
                }
            }
        }

        # Install the latest BuildHelpers module from a custom registered repository
        # and bypass the catalog signing check.

        # Examples of private repositories include:
        # - PSPrivateGallery
        # - Artifactory
        # - ProGet
        # - Gitlab

    .EXAMPLE
        @{
            'vmware.powercli' = @{
                Parameters = @{
                    Prerelease = $true
                }
            }
        }

        # Install the latest version of PowerCLI, allowing prerelease versions.
#>

[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [AllowNull()]
    [string]$Repository = 'PSGallery', # From Parameters...

    [bool]$NoClobber = $false,

    [bool]$AcceptLicense,

    [bool]$Prerelease,

    [switch]$Import,

    [ValidateSet('Test', 'Install', 'Import')]
    [string[]]$PSDependAction = @('Install')
)

# Extract data from Dependency
$DependencyName = $Dependency.DependencyName
$Name = $Dependency.Name
if(-not $Name)
{
    $Name = $DependencyName
}

$Version = $Dependency.Version
if(-not $Version)
{
    $Version = 'latest'
}

# We use target as a proxy for Scope
if(-not $Dependency.Target)
{
    $Scope = 'CurrentUser'
}
else
{
    $Scope = $Dependency.Target
}

$Credential = $Dependency.Credential

if('AllUsers', 'CurrentUser' -notcontains $Scope)
{
    $command = 'save'
}
else
{
    $command = 'install'
}

if(-not (Get-PackageProvider -Name Nuget))
{
    # Grab nuget bits.
    $null = Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null
}

Write-Verbose -Message "Getting dependency [$name] from PowerShell repository [$Repository]"

# Validate that $target has been setup as a valid PowerShell repository,
#   but allow to rely on all PS repos registered.
if($Repository)
{
    $validRepo = Get-PSResourceRepository -Name $Repository -Verbose:$false -ErrorAction SilentlyContinue
    if (-not $validRepo)
    {
        Write-Error "[$Repository] has not been setup as a valid PowerShell repository."
        return
    }
}

$params = @{
    Name       = $Name
    NoClobber  = $NoClobber
    Verbose    = $VerbosePreference
}

if($PSBoundParameters.ContainsKey('Prerelease'))
{
    $params.Add('Prerelease', $Prerelease)
}

if($PSBoundParameters.ContainsKey('AcceptLicense'))
{
    $params.Add('AcceptLicense', $AcceptLicense)
}

if($Repository)
{
    $params.Add('Repository',$Repository)
}

if($Version -and $Version -ne 'latest')
{
    $Params.add('RequiredVersion', $Version)
}

if($Credential)
{
    $Params.add('Credential', $Credential)
}

# This code works for both install and save scenarios.
if($command -eq 'Save')
{
    $ModuleName =  Join-Path $Scope $Name
    $Params.Remove('NoClobber')
}
elseif ($Command -eq 'Install')
{
    $ModuleName = $Name
}

$availableParameters = (Get-Command "Install-Module").Parameters
$tempParams = $Params.Clone()
foreach($thisParameter in $Params.Keys)
{
    if(-Not ($availableParameters.ContainsKey($thisParameter)))
    {
        Write-Verbose -Message "Removing parameter [$thisParameter] from [Install-Module] as it is not available"
        $tempParams.Remove($thisParameter)
    }
}
$Params = $tempParams.Clone()

Add-ToPsModulePathIfRequired -Dependency $Dependency -Action $PSDependAction

$Existing = $null
$Existing = Get-Module -ListAvailable -Name $ModuleName -ErrorAction SilentlyContinue

if($Existing)
{
    Write-Verbose "Found existing module [$Name]"
    # Thanks to Brandon Padgett!
    $ExistingVersion = $Existing | Measure-Object -Property Version -Maximum | Select-Object -ExpandProperty Maximum
    $FindModuleParams = @{Name = $Name }
    if($Repository)
    {
        $FindModuleParams.Add('Repository', $Repository)
    }
    if($Credential)
    {
        $FindModuleParams.Add('Credential', $Credential)
    }
    if($Prerelease)
    {
        $FindModuleParams.Add('Prerelease', $Prerelease)
    }

    # Version string, and equal to current
    if($Version -and $Version -ne 'latest' -and $Version -eq $ExistingVersion)
    {
        Write-Verbose "You have the requested version [$Version] of [$Name]"
        # Conditional import
        Import-PSDependModule -Name $ModuleName -Action $PSDependAction -Version $ExistingVersion

        if($PSDependAction -contains 'Test')
        {
            return $true
        }
        return $null
    }

    Write-verbose "$($Repository)"
    $GalleryVersion = Find-PSResource @FindModuleParams | Measure-Object -Property Version -Maximum | Select-Object -ExpandProperty Maximum
    [System.Version]$parsedVersion = $null
    [System.Management.Automation.SemanticVersion]$parsedSemanticVersion = $null
    [System.Management.Automation.SemanticVersion]$parsedTempSemanticVersion = $null
    $isGalleryVersionLessEquals = if (
        [System.Management.Automation.SemanticVersion]::TryParse($ExistingVersion, [ref]$parsedSemanticVersion) -and
        [System.Management.Automation.SemanticVersion]::TryParse($GalleryVersion, [ref]$parsedTempSemanticVersion)
    )
    {
        $GalleryVersion -le $parsedSemanticVersion
    }
    elseif ([System.Version]::TryParse($ExistingVersion, [ref]$parsedVersion))
    {
        $GalleryVersion -le $parsedVersion
    }

    # latest, and we have latest
    if( $Version -and ($Version -eq 'latest' -or $Version -eq '') -and $isGalleryVersionLessEquals)
    {
        Write-Verbose "You have the latest version of [$Name], with installed version [$ExistingVersion] and PSGallery version [$GalleryVersion]"
        # Conditional import
        Import-PSDependModule -Name $ModuleName -Action $PSDependAction -Version $ExistingVersion

        if($PSDependAction -contains 'Test')
        {
            return $True
        }
        return $null
    }
    Write-Verbose "Continuing to install [$Name]: Requested version [$version], existing version [$ExistingVersion]"
}

#No dependency found, return false if we're testing alone...
if( $PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1)
{
    return $False
}

if($PSDependAction -contains 'Install')
{
    if('AllUsers', 'CurrentUser' -contains $Scope)
    {
        Write-Verbose "Installing [$Name] with scope [$Scope]"
        Write-verbose "$params"
        Install-PSResource @params
    }
    else
    {
        Write-Verbose "Saving [$Name] with path [$Scope]"
        Write-Verbose "Creating directory path to [$Scope]"
        if(-not (Test-Path $Scope -ErrorAction SilentlyContinue))
        {
            $Null = New-Item -ItemType Directory -Path $Scope -Force -ErrorAction SilentlyContinue
        }
        Save-PSResource @params -Path $Scope
    }
}

# Conditional import
$importVs = $params['RequiredVersion']
Import-PSDependModule -Name $ModuleName -Action $PSDependAction -Version $importVs