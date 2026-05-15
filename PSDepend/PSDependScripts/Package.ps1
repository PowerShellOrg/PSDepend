<#
    .SYNOPSIS
        EXPERIMENTAL: Installs a package using the PackageManagement module

    .DESCRIPTION
        EXPERIMENTAL: Installs a package using the PackageManagement module

        Relevant Dependency metadata:
            Name: The name for this Package
            Version: Used to identify existing installs meeting this criteria, and as RequiredVersion for installation.  Defaults to 'latest'
            Target: Used as 'Scope' for PowerShellGet provider, Destination for Nuget provider
            Source: Package source to use (Get-PackageSource, Register-PackageSource)
            Parameters: Every parameter you specify is splatted against Install-Package

        If you don't have the Nuget package provider, we install it for you

    .PARAMETER ProviderName
        Optionally specify the Provider name to use (Get-PackageProvider, Register-PackageProvider)

    .PARAMETER PSDependAction
        Test, Install, or Import the module.  Defaults to Install

        Test: Return true or false on whether the dependency is in place
        Install: Install the dependency

    .EXAMPLE
        @{
            jquery = @{
                DependencyType = 'Package'
                Target = 'C:\MyProject'
                Source = 'nuget.org'
            }
        }

        # Install jquery from the nuget.org PackageSource to C:\MyProject
        # IMPORTANT: Only certain providers support specifying a target destination

    .EXAMPLE
        @{
            jquery = @{
                DependencyType = 'Package'
                Source = 'https://my.internal.nuget.feed/api'
                Target = 'C:\MyProject'
                Parameters = @{
                    ProviderName = 'nuget'
                }
            }
        }

        # Install jquery from my internal nuget feed to C:\MyProject

#>
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [ValidateSet('Test', 'Install')]
    [string[]]$PSDependAction = @('Install'),

    [String]$ProviderName
)

# Extract data from Dependency
    $DependencyName = $Dependency.DependencyName
    $Source = $Dependency.Source
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

$PackageSources = @( Get-PackageSource )
if($PackageSources.Name -notcontains $Source -and -not $PSBoundParameters.ContainsKey('ProviderName'))
{
    Write-Error "PackageSource [$Source] is not valid.  Valid sources:`n$($PackageSources.ProviderName | Out-String)"
    return
}

$PackageProviders = @( Get-PackageProvider )
if($PSBoundParameters.ContainsKey('ProviderName') -and $PackageProviders.Name -notcontains $ProviderName)
{
    Write-Error "ProviderName [$ProviderName] is not valid.  Valid sources:`n$($PackageProviders.Name | Out-String)"
    return
}

Write-Verbose -Message "Getting dependency [$name] from Package source [$Source]"

if($PSBoundParameters.ContainsKey('ProviderName'))
{
    $ThisProvider = $ProviderName
}
else # Pick providername from this packagesource
{
    $ThisProvider = $PackageSources | Where-Object {$_.Name -eq $Source} | Select-Object -ExpandProperty ProviderName
}

$GetParam = @{
    Name = $Name
    ProviderName = $ThisProvider
    ErrorAction = 'SilentlyContinue'
}
$InstallParam = @{
    Name = $Name
    Source = $Source
    Force = $True
}
if($Version -notlike 'latest')
{
    $GetParam.add('RequiredVersion', $Version)
    $InstallParam.add('RequiredVersion', $Version)
}

# Parse target for PowerShellGet
If($ThisProvider -eq 'PowerShellGet')
{
    $ValidScope = 'CurrentUser', 'AllUsers'
    if(-not $Dependency.Target)
    {
        $Scope = 'AllUsers'
    }
    else
    {
        $Scope = $Dependency.Target
    }
    if($ValidScope -contains $Scope)
    {
        $InstallParam.Add('Scope', $Scope)
    }
}
# Parse target for Nuget
if($ThisProvider -eq 'Nuget')
{
    if(-not $Dependency.Target)
    {
        throw 'Nuget provider requires that you specify a target destination.  Use the dependency Target for this.'
    }
    $GetParam.Add('Destination', $Dependency.Target)
    $InstallParam.Add('Destination', $Dependency.Target)
}


# Add arbitrary keys to support DynamicOptions...
if($Dependency.Parameters.Keys.Count -gt 0)
{
    foreach($Key in $Dependency.Parameters.Keys)
    {
        if(-not $InstallParam.ContainsKey($Key))
        {
            $InstallParam.add($Key, $Dependency.Parameters.$Key)
        }
        else
        {
            $InstallParam.$Key = $Dependency.Parameters.$Key
        }
    }
}

$Existing = $null
Write-Verbose "Running Get-Package with $($GetParam | Out-String)"
$Existing = Get-Package @GetParam

if($Existing)
{
    Write-Verbose "Found existing package [$Name]"
    # Thanks to Brandon Padgett!
    $ExistingVersion = $Existing | Measure-Object -Property Version -Maximum | Select-Object -ExpandProperty Maximum
    $GetSourceVersion = { Find-Package -Name $Name -Source $Source | Measure-Object -Property Version -Maximum | Select-Object -ExpandProperty Maximum }
    
    # Version string, and equal to current
    if( $Version -and $Version -ne 'latest' -and $Version -eq $ExistingVersion)
    {
        Write-Verbose "You have the requested version [$Version] of [$Name]"
        if($PSDependAction -contains 'Test')
        {
            return $True
        }
        return $null
    }
    
    # latest, and we have latest
    if( $Version -and
        ($Version -eq 'latest' -or $Version -like '') -and
        ($SourceVersion = (& $GetSourceVersion)) -le $ExistingVersion
    )
    {
        Write-Verbose "You have the latest version of [$Name], with installed version [$ExistingVersion] and package source version [$SourceVersion]"
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
    Write-Verbose "Installing [$Name] with params $($InstallParam | Out-String)"
    Install-Package @InstallParam
}

