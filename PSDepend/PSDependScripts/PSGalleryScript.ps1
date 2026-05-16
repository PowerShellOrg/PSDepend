<#
    .SYNOPSIS
        Installs a script from a PowerShell repository like the PowerShell Gallery.

    .DESCRIPTION
        Installs a script from a PowerShell repository like the PowerShell Gallery.

        Relevant Dependency metadata:
            Name: The name for this script
            Version: Used to identify existing installs meeting this criteria, and as RequiredVersion for installation.  Defaults to 'latest'
            Target: Used as 'Scope' for Install-Script.  If this is a path, we use Save-Script with this path.  Defaults to 'AllUsers'
			Credential: The username and password used to authenticate against the private repository

        If you don't have the Nuget package provider, we install it for you

    .PARAMETER Repository
        PSRepository to download from.  Defaults to PSGallery

    .PARAMETER AcceptLicense
        Accepts the license agreement during installation.
        
    .PARAMETER AllowPrerelease
        If specified, allow for prerelease.

        If specified along with version 'latest', a prerelease will be selected if it is the latest version

        Sorting assumes you name prereleases appropriately (i.e. alpha < beta < gamma)

    .PARAMETER PSDependAction
        Test, Install, or Import the script.  Defaults to Install

        Test: Return true or false on whether the dependency is in place
        Install: Install the dependency
        Import: Import the dependency

    .PARAMETER NoPathUpdate
        If specified, don't update the path. Defaults to false.


    .EXAMPLE
        @{
            'Get-CurrentUser' = @{
                Version = 'latest'
                Parameters = @{
                    NoPathUpdate = $true
                }
            'Get-RemoteProgram' = ''
            'Update-Windows' = '1.1.0'
        }

        # From the PSGallery repository (PowerShellGallery.com)...
            # Install the latest Get-CurrentUser and Get-RemoteProgram scripts ('latest' and '' both evaluate to latest)
            # Install version 1.1.0 of Update-Windows script

    .EXAMPLE
        @{
            'Get-CurrentUser' = @{
                Target = 'C:\test'
            }
        }

        # Install the latest Get-CurrentUser script from PSGallery to C:\test (i.e. C:\test\Get-CurrentUser.ps1 will be the script)
        # No version is specified - we assume latest in this case.

    .EXAMPLE
        @{
            'Get-CurrentUser' = @{
                Parameters @{
                    Repository = 'PSPrivateGallery'
                }
            }
        }

        # Install the latest Get-CurrentUser script from a custom gallery* that you registered
        # No version is specified - we assume latest in this case.

        # * Perhaps you use this https://github.com/PowerShell/PSPrivateGallery, or Artifactory, ProGet, etc.
    
    .EXAMPLE
        @{
            'Get-CurrentUser' = @{
                Parameters = @{
                    NoPathUpdate = $true
                }
            }
        }
        # Install the latest version of Get-CurrentUser script, disabling the path update.
#>
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [AllowNull()]
    [string]$Repository = 'PSGallery', # From Parameters...

    [bool]$AcceptLicense,

    [bool]$AllowPrerelease,

    [bool]$NoPathUpdate,

    [bool]$IncludeDependencies,

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
        $Scope = 'AllUsers'
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
if($Repository) {
    $validRepo = Get-PSRepository -Name $Repository -Verbose:$false -ErrorAction SilentlyContinue
        if (-not $validRepo) {
            Write-Error "[$Repository] has not been setup as a valid PowerShell repository."
            return
        }
}

$params = @{
    Name               = $Name
    NoPathUpdate       = $NoPathUpdate
    Verbose            = $VerbosePreference
    Force              = $True
}

if($PSBoundParameters.ContainsKey('AllowPrerelease')){
    $params.Add('AllowPrerelease', $AllowPrerelease)
}

if($PSBoundParameters.ContainsKey('AcceptLicense')){
    $params.Add('AcceptLicense', $AcceptLicense)
}

if($Repository) {
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
    $Params.Remove('NoPathUpdate')
}
elseif ($Command -eq 'Install')
{
    $ModuleName = $Name
}

# Only use "SkipPublisherCheck" (and other) parameter if "Install-Script" supports it
$availableParameters = (Get-Command "Install-Script").Parameters
$tempParams = $Params.Clone()
foreach($thisParameter in $Params.Keys)
{
    if(-Not ($availableParameters.ContainsKey($thisParameter)))
    {
        Write-Verbose -Message "Removing parameter [$thisParameter] from [Install-Script] as it is not available"
        $tempParams.Remove($thisParameter)
    }
}
$Params = $tempParams.Clone()

# @matthewjdegarmo doesn't think this is needed for scripts
# Add-ToPsModulePathIfRequired -Dependency $Dependency -Action $PSDependAction

$Existing = $null
$Existing = Get-Module -ListAvailable -Name $ModuleName -ErrorAction SilentlyContinue

if($Existing)
{
    Write-Verbose "Found existing script [$Name]"
    # Thanks to Brandon Padgett!
    $ExistingVersion = $Existing | Measure-Object -Property Version -Maximum | Select-Object -ExpandProperty Maximum
    $FindScriptParams = @{Name = $Name}
    if($Repository) {
        $FindScriptParams.Add('Repository', $Repository)
    }
    if($Credential)
    {
        $FindScriptParams.Add('Credential', $Credential)
    }
    if($AllowPrerelease)
    {
        $FindScriptParams.Add('AllowPrerelease', $AllowPrerelease)
    }

    # Version string, and equal to current
    if($Version -and $Version -ne 'latest' -and $Version -eq $ExistingVersion)
    {
        Write-Verbose "You have the requested version [$Version] of [$Name]"
        # Conditional import
        # @matthewjdegarmo doesn't think this is needed for scripts
        # Import-PSDependModule -Name $ModuleName -Action $PSDependAction -Version $ExistingVersion

        if($PSDependAction -contains 'Test')
        {
            return $true
        }
        return $null
    }

    $GalleryVersion = Find-Script @FindScriptParams | Measure-Object -Property Version -Maximum | Select-Object -ExpandProperty Maximum
    [System.Version]$parsedVersion = $null
    [System.Management.Automation.SemanticVersion]$parsedSemanticVersion = $null
    [System.Management.Automation.SemanticVersion]$parsedTempSemanticVersion = $null
    $isGalleryVersionLessEquals = if (
        [System.Management.Automation.SemanticVersion]::TryParse($ExistingVersion, [ref]$parsedSemanticVersion) -and
        [System.Management.Automation.SemanticVersion]::TryParse($GalleryVersion, [ref]$parsedTempSemanticVersion)
    ) {
        $GalleryVersion -le $parsedSemanticVersion
    }
    elseif ([System.Version]::TryParse($ExistingVersion, [ref]$parsedVersion)) {
        $GalleryVersion -le $parsedVersion
    }

    # latest, and we have latest
    if( $Version -and ($Version -eq 'latest' -or $Version -eq '') -and $isGalleryVersionLessEquals)
    {
        Write-Verbose "You have the latest version of [$Name], with installed version [$ExistingVersion] and PSGallery version [$GalleryVersion]"
        # Conditional import
        # @matthewjdegarmo doesn't think this is needed for scripts
        # Import-PSDependModule -Name $ModuleName -Action $PSDependAction -Version $ExistingVersion

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
        #Account for [-IncludeDependencies] on Find-Script. This is dependency mapping outside of the PSDepend file.
        if($IncludeDependencies)
        {
            $FindScriptParams.Add('IncludeDependencies', $IncludeDependencies)
            $FindScriptParams.Add('RequiredVersion', $Version)

            # Need to remove Name and RequiredVersion, that info is coming across the Pipeline.
            $InstallParams = $params.clone()
            $InstallParams.Remove('Name')
            $InstallParams.Remove('RequiredVersion')
            
            Find-Script @FindScriptParams | Install-Script @InstallParams -Scope $Scope
        } Else {
            Install-Script @params -Scope $Scope
        }
    }
    else
    {
        Write-Verbose "Saving [$Name] with path [$Scope]"
        # @matthewjdegarmo doesn't think this is needed for scripts
        # Write-Verbose "Creating directory path to [$Scope]"
        # if(-not (Test-Path $Scope -ErrorAction SilentlyContinue))
        # {
        #     $Null = New-Item -ItemType Directory -Path $Scope -Force -ErrorAction SilentlyContinue
        # }
        Save-Script @params -Path $Scope
    }
}

# Conditional import
# @matthewjdegarmo doesn't think this is needed for scripts
# $importVs = $params['RequiredVersion']
# Import-PSDependModule -Name $ModuleName -Action $PSDependAction -Version $importVs
