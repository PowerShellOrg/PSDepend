<#
    .SYNOPSIS
        Installs a Chocolatey package a repository.

    .DESCRIPTION
        Installs a package from a Chocolatey repository like Chocolatey.org.

        Relevant Dependency metadata:
            Name: The name of the package
            Version: Used to identify existing installs meeting this criteria. Defaults to 'latest'
            Source: Source Uri. Defaults to https://chocolatey.org/api/v2/

    .PARAMETER Force
        If specified and the package is already installed, force the install again.

    .PARAMETER PSDependAction
        Test, or Install the package. Defaults to Install

        Test: Return true or false on whether the dependency is in place
        Install: Install the dependency

    .EXAMPLE

        @{
            'git' = @{
                DependencyType = 'Chocolatey'
                Version = '2.0.2'
            }
        }

        # Install version 2.0.2 of git via Chocolatey.org

    .EXAMPLE

        @{
            'git' = @{
                DependencyType = 'Chocolatey'
                Source = 'https://feed.mycompany.com'
            }
        }

        # Install the latest version of git from the Chocolatey feed at https://feed.mycompany.com

    .EXAMPLE

        @{
            PSDependOptions = @{
                DependencyType = 'Chocolatey'
            }
            'git.portable' = @{
                Version = 'latest'
                Parameters = @{
                    Force = $true
                }
            }
            'lessmsi' = 'latest'
            'putty' = 'latest'
        }

        # Installs the list of Chocolatey packages from Chocolatey.org using the Global PSDependOptions to limit repetition.

#>
[CmdletBinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [switch]$Force,

    [string]$ChocoInstallScriptUrl = 'https://chocolatey.org/install.ps1',

    [ValidateSet('Test', 'Install')]
    [string[]]$PSDependAction = @('Install')
)

function Get-ChocoInstalledPackage
{
    [CmdletBinding()]
    param (
        [string]$Name
    )

    $chocoParams = @('list', "$Name", '--limit-output', '--exact', '--local-only')
    Invoke-ExternalCommand -Command 'choco.exe' -Arguments $chocoParams -PassThru | ConvertFrom-Csv -Header 'Name', 'Version' -Delimiter "|"
}

function Get-ChocoLatestPackage
{
    [CmdletBinding()]
    param (
        [string]$Name,

        [string]$Source,

        [Management.Automation.PSCredential]$Credential
    )

    $chocoParams = @('list', "$Name", '--limit-output', '--exact')
    if ($Source)
    {
        $chocoParams += "--source='$Source'"
    }

    if ($Credential)
    {
        $username = $credential.UserName
        $password = $credential.GetNetworkCredential().Password
        $chocoParams += "--username='$username'"
        $chocoParams += "--password='$password'"
    }

    Invoke-ExternalCommand -Command 'choco.exe' -Arguments $chocoParams -PassThru | ConvertFrom-Csv -Header 'Name', 'Version' -Delimiter "|"
}

function Invoke-ChocoInstallPackage
{
    [CmdletBinding()]
    param (
        [string]$Name,

        [string]$Version,

        [string]$Source,

        [switch]$Force,

        [Management.Automation.PSCredential]$Credential
    )

    $chocoParams = @('upgrade', "$Name", '--limit-output', '--exact', '--no-progress', '--allow-downgrade')
    if ($Force.IsPresent)
    {
        $chocoParams += "--force"
    }

    if ($Source)
    {
        $chocoParams += "--source='$Source'"
    }

    if ($Version -and $Version -ne 'latest' -and $Version -ne '')
    {
        $chocoParams += "--version='$Version'"
    }

    if ($Credential)
    {
        $username = $credential.UserName
        $password = $credential.GetNetworkCredential().Password
        $chocoParams += "--username='$username'"
        $chocoParams += "--password='$password'"
    }

    Invoke-ExternalCommand -Command 'choco.exe' -Arguments $chocoParams
}

# Extract data from Dependency
$Name = $Dependency.Name
if (-not $Name)
{
    $Name = $Dependency.DependencyName
}

$Version = $Dependency.Version
if (-not $Dependency.Version -or $Version -eq '')
{
    $Version = 'latest'
}

$Source = $Dependency.Source
if (-not $Dependency.Source -or $Source -eq '')
{
    $Source = 'https://chocolatey.org/api/v2/'
}

$Credential = $Dependency.Credential

if (-not (Get-Command -Name 'choco.exe' -ErrorAction SilentlyContinue)) {
    Write-Verbose "Chocolatey is not installed. Installing from [$ChocoInstallScriptUrl]"
    # download and run the Chocolatey script
    # Add TLS 1.2 support
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    do
    {
        $scriptPath = Join-Path -Path $env:TEMP -ChildPath ("{0}.ps1" -f [GUID]::NewGuid().ToString())
    } while (Test-Path -Path $scriptPath)

    try
    {
        Invoke-WebRequest -UseBasicParsing -Uri $ChocoInstallScriptUrl -OutFile $scriptPath
        & $scriptPath
    }
    catch
    {
        throw "Unable to install Chocolatey from '$scriptUrl'."
    }
}

# if this is a forced install we don't need to check anything, just install the package version requested
if ($Force.IsPresent -and $PSDependAction -contains 'Install')
{
    $params = @{
        Name    = $Name
        Version = $Version
        Source  = $Source
        Force   = $Force.IsPresent
    }

    if ($Credential)
    {
        $params.Credential = $Credential
    }

    Write-Verbose "Forced install of Chocolatey package [$Name] from Chocolatey source [$Source] with Version [$Version]"
    Invoke-ChocoInstallPackage @params

    return
}

# get the package if it is installed
Write-Verbose "Getting package [$Name] version, if it is installed."
$existingVersion = (Get-ChocoInstalledPackage -Name $Name).Version
if ($existingVersion)
{
    Write-Verbose "Found package [$Name] installed with version [$Version]."
}
else {
    Write-Verbose "Package [$Name] not installed."
}

# Version latest requested, and equal to current
if ($Version -ne 'latest' -and $Version -eq $existingVersion)
{
    Write-Verbose "You have the requested version [$Version] of [$Name]"
    if($PSDependAction -contains 'Test')
    {
        return $true
    }

    return
}

# get the latest version from the source
$repoParams = @{
    Name   = $Name
    Source = $Source
}
if ($Credential)
{
    $repoParams.Credential = Credential
}

Write-verbose "Getting latest package [$Name] version from source [$Source]."
$repositoryVersion = (Get-ChocoLatestPackage @repoParams).Version
if ($repositoryVersion)
{
    Write-Verbose "Found package [$Name] version [$Version] on source [$Source]."
}
else
{
    Write-Verbose "Package [$Name] not found on source [$Source]. Nothing more can be done."
    return  # cannot continue
}

# If the version in the remote repository is less than or equal to the version installed, then we have the latest already
if ($Version -eq 'latest' -and ([System.Version]$repositoryVersion -le [System.Version]$existingVersion))
{
    Write-Verbose "You have the latest version of [$Name], with installed version [$existingVersion] and Source version [$repositoryVersion]"
    if($PSDependAction -contains 'Test')
    {
        return $true
    }

    return
}

# if we get here then we do not have the latest version installed and that is what has been requested
Write-Verbose "You do not have the version requested of [$Name]: Requested version [$Version], existing version [$existingVersion], available version [$repositoryVersion]."
if ($PSDependAction -contains 'Install')
{
    $params = @{
        Name    = $Name
        Version = $Version
        Source  = $Source
        Force   = $Force.IsPresent
    }

    if ($Credential)
    {
        $params.Credential = $Credential
    }

    Invoke-ChocoInstallPackage @params
}
elseif ($PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1)
{
    return $false
}