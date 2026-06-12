<#
    .SYNOPSIS
    Installs a package from a Chocolatey repository.

    .DESCRIPTION
    Installs a package from a Chocolatey repository like the Chocolatey community repository.

    Relevant Dependency metadata:
        Name: The name of the package
        Version: Used to identify existing installs meeting this criteria. Defaults to 'latest'
        Source: Source Uri. Defaults to https://community.chocolatey.org/api/v2/

    .PARAMETER Dependency
    Dependency to process

    .PARAMETER Force
    If specified and the package is already installed, force the install again.

    .PARAMETER ChocoInstallScriptUrl
    Url to the script used to bootstrap Chocolatey when choco.exe is not found.
    Defaults to https://community.chocolatey.org/install.ps1

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

    # Install version 2.0.2 of git from the Chocolatey community repository

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

    # Installs the list of Chocolatey packages from the Chocolatey community repository using the Global PSDependOptions to limit repetition.

#>
[CmdletBinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [PSObject[]]$Dependency,

    [switch]$Force,

    [string]$ChocoInstallScriptUrl = 'https://community.chocolatey.org/install.ps1',

    [ValidateSet('Test', 'Install')]
    [string[]]$PSDependAction = @('Install')
)

function Get-ChocoVersion {
    [CmdletBinding()]
    param ()

    $invokeExternalCommandSplat = @{
        Command   = 'choco.exe'
        Arguments = @('--version')
        PassThru  = $true
    }
    $rawVersion = [string](Invoke-ExternalCommand @invokeExternalCommandSplat | Select-Object -First 1)
    [System.Version]$parsedVersion = $null
    # Strip prerelease/build metadata (e.g. 2.2.2-beta) before parsing
    if ([System.Version]::TryParse(($rawVersion -replace '[-+].*$'), [ref]$parsedVersion)) {
        $parsedVersion
    }
    else {
        # Assume a modern CLI when the version cannot be determined
        [System.Version]'2.0'
    }
}

function Get-ChocoInstalledPackage {
    [CmdletBinding()]
    param (
        [string]$Name
    )

    $chocoParams = @(
        'list',
        "$Name",
        '--limit-output',
        '--exact'
    )
    # Chocolatey 2.0 removed --local-only ('choco list' is now local-only by default);
    # before 2.0, 'choco list' queried remote sources unless the flag was passed
    if ((Get-ChocoVersion).Major -lt 2) {
        $chocoParams += '--local-only'
    }
    $invokeExternalCommandSplat = @{
        Command   = 'choco.exe'
        Arguments = $chocoParams
        PassThru  = $true
    }
    $convertFromCsvSplat = @{
        Header    = 'Name', 'Version'
        Delimiter = "|"
    }
    Invoke-ExternalCommand @invokeExternalCommandSplat | ConvertFrom-Csv @convertFromCsvSplat
}

function Get-ChocoLatestPackage {
    [CmdletBinding()]
    param (
        [string]$Name,

        [string]$Source,

        [Management.Automation.PSCredential]$Credential
    )

    # 'choco search' queries remote sources on both 1.x and 2.x; 'choco list' stopped
    # querying remote sources in Chocolatey 2.0 and rejects URL sources (issue #187)
    $chocoParams = @('search', "$Name", '--limit-output', '--exact')
    if ($Source) {
        $chocoParams += "--source='$Source'"
    }

    if ($Credential) {
        $username = $credential.UserName
        $password = $credential.GetNetworkCredential().Password
        $chocoParams += "--username='$username'"
        $chocoParams += "--password='$password'"
    }

    $invokeExternalCommandSplat = @{
        Command   = 'choco.exe'
        Arguments = $chocoParams
        PassThru  = $true
    }
    $convertFromCsvSplat = @{
        Header    = 'Name', 'Version'
        Delimiter = "|"
    }
    Invoke-ExternalCommand @invokeExternalCommandSplat | ConvertFrom-Csv @convertFromCsvSplat
}

function Invoke-ChocoInstallPackage {
    [CmdletBinding()]
    param (
        [string]$Name,

        [string]$Version,

        [string]$Source,

        [switch]$Force,

        [Management.Automation.PSCredential]$Credential
    )

    $chocoParams = @(
        'upgrade',
        "$Name",
        '--limit-output',
        '--exact',
        '--no-progress',
        '--allow-downgrade',
        '--yes' # Ensure that we do not get prompted to confirm the install
    )
    if ($Force.IsPresent) {
        $chocoParams += "--force"
    }

    if ($Source) {
        $chocoParams += "--source='$Source'"
    }

    if ($Version -and $Version -ne 'latest' -and $Version -ne '') {
        $chocoParams += "--version='$Version'"
    }

    if ($Credential) {
        $username = $credential.UserName
        $password = $credential.GetNetworkCredential().Password
        $chocoParams += "--username='$username'"
        $chocoParams += "--password='$password'"
    }

    $invokeExternalCommandSplat = @{
        Command   = 'choco.exe'
        Arguments = $chocoParams
    }
    Invoke-ExternalCommand @invokeExternalCommandSplat
}

# Extract data from Dependency
$Name = $Dependency.Name
if (-not $Name) {
    $Name = $Dependency.DependencyName
}

$Version = $Dependency.Version
if (-not $Dependency.Version -or $Version -eq '') {
    $Version = 'latest'
}

$Source = $Dependency.Source
if (-not $Dependency.Source -or $Source -eq '') {
    $Source = 'https://community.chocolatey.org/api/v2/'
}

$Credential = $Dependency.Credential

if (-not (Get-Command -Name 'choco.exe' -ErrorAction SilentlyContinue)) {
    Write-Verbose "Chocolatey is not installed. Installing from [$ChocoInstallScriptUrl]"
    # download and run the Chocolatey script
    # Add TLS 1.2 support
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    do {
        $scriptPath = Join-Path -Path $env:TEMP -ChildPath ("{0}.ps1" -f [GUID]::NewGuid().ToString())
    } while (Test-Path -Path $scriptPath)

    try {
        Invoke-WebRequest -UseBasicParsing -Uri $ChocoInstallScriptUrl -OutFile $scriptPath
        & $scriptPath
    }
    catch {
        throw "Unable to install Chocolatey from '$ChocoInstallScriptUrl'."
    }
}

# If this is a forced install we don't need to check anything,
# just install the package version requested
if ($Force.IsPresent -and $PSDependAction -contains 'Install') {
    $params = @{
        Name    = $Name
        Version = $Version
        Source  = $Source
        Force   = $Force.IsPresent
    }

    if ($Credential) {
        $params.Credential = $Credential
    }

    Write-Verbose "Forced install of Chocolatey package [$Name] from Chocolatey source [$Source] with Version [$Version]"
    Invoke-ChocoInstallPackage @params

    return
}

# get the package if it is installed
Write-Verbose "Getting package [$Name] version, if it is installed."
$existingVersion = (Get-ChocoInstalledPackage -Name $Name).Version
if ($existingVersion) {
    Write-Verbose "Found package [$Name] installed with version [$existingVersion]."
}
else {
    Write-Verbose "Package [$Name] not installed."
}

# Specific version requested, and equal to current
if ($Version -ne 'latest' -and (Test-VersionEquality -ReferenceVersion $Version -DifferenceVersion $existingVersion)) {
    Write-Verbose "You have the requested version [$Version] of [$Name]"
    if ($PSDependAction -contains 'Test') {
        return $true
    }

    return
}

# get the latest version from the source
$repoParams = @{
    Name   = $Name
    Source = $Source
}
if ($Credential) {
    $repoParams.Credential = $Credential
}

Write-Verbose "Getting latest package [$Name] version from source [$Source]."
$repositoryVersion = (Get-ChocoLatestPackage @repoParams).Version
if ($repositoryVersion) {
    Write-Verbose "Found package [$Name] version [$repositoryVersion] on source [$Source]."
}
else {
    Write-Verbose "Package [$Name] not found on source [$Source]. Nothing more can be done."
    return  # cannot continue
}

# If the version in the remote repository is less than or equal to the version installed, then we have the latest already
[System.Version]$parsedRepositoryVersion = $null
[System.Version]$parsedExistingVersion = $null
[System.Management.Automation.SemanticVersion]$parsedRepositorySemanticVersion = $null
[System.Management.Automation.SemanticVersion]$parsedExistingSemanticVersion = $null
$haveLatest = if (
    [System.Management.Automation.SemanticVersion]::TryParse([string]$repositoryVersion, [ref]$parsedRepositorySemanticVersion) -and
    [System.Management.Automation.SemanticVersion]::TryParse([string]$existingVersion, [ref]$parsedExistingSemanticVersion)
) {
    $parsedRepositorySemanticVersion -le $parsedExistingSemanticVersion
}
elseif (
    [System.Version]::TryParse([string]$repositoryVersion, [ref]$parsedRepositoryVersion) -and
    [System.Version]::TryParse([string]$existingVersion, [ref]$parsedExistingVersion)
) {
    $parsedRepositoryVersion -le $parsedExistingVersion
}
else {
    $false
}
if ($Version -eq 'latest' -and $haveLatest) {
    Write-Verbose "You have the latest version of [$Name], with installed version [$existingVersion] and Source version [$repositoryVersion]"
    if ($PSDependAction -contains 'Test') {
        return $true
    }

    return
}

# if we get here then we do not have the latest version installed and that is
# what has been requested
Write-Verbose "You do not have the version requested of [$Name]: Requested version [$Version], existing version [$existingVersion], available version [$repositoryVersion]."
if ($PSDependAction -contains 'Install') {
    $params = @{
        Name    = $Name
        Version = $Version
        Source  = $Source
        Force   = $Force.IsPresent
    }

    if ($Credential) {
        $params.Credential = $Credential
    }

    Invoke-ChocoInstallPackage @params
}
elseif ($PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1) {
    return $false
}
