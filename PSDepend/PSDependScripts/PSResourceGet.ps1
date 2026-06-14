<#
    .SYNOPSIS
        Installs a PowerShell resource from a PowerShell repository using PSResourceGet.

    .DESCRIPTION
        Installs a PowerShell module from a PowerShell repository (such as the PowerShell Gallery)
        using PSResourceGet (Microsoft.PowerShell.PSResourceGet), the successor to the deprecated
        PowerShellGet v2 module. PSResourceGet must be installed before using this provider.

        Prefer this provider over PSGalleryModule for new projects. PSGalleryModule targets
        PowerShellGet v2 (Install-Module); this provider targets PSResourceGet v3 (Install-PSResource).

        Relevant Dependency metadata:
            Name:       The name of the module to install
            Version:    Used to identify existing installs and as -Version for installation.
                        Supports NuGet range syntax (e.g. '[1.0.0, ]'). Defaults to 'latest'.
            Target:     Used as -Scope for Install-PSResource (CurrentUser or AllUsers).
                        If this is a filesystem path, Save-PSResource is used instead.
                        Defaults to 'CurrentUser'.
            AddToPath:  If Target is a filesystem path, prepend that path to $env:PSModulePath.
            Credential: A [PSCredential] for authenticating against a private repository.
                        Use Get-Credential or [PSCredential]::new() to construct one.

        This provider calls the following PSResourceGet cmdlets:
            - Find-PSResource
            - Install-PSResource
            - Save-PSResource

    .PARAMETER Dependency
        The PSDepend.Dependency object passed by Invoke-PSDepend. Not supplied directly by the caller.

    .PARAMETER Repository
        PSResource repository to download from.
        Defaults to PSGallery.

    .PARAMETER NoClobber
        Prevents installation if the module would overwrite commands already present on the system.

    .PARAMETER AcceptLicense
        Suppresses the license acceptance prompt during installation.

    .PARAMETER Prerelease
        If specified, allows installation of prerelease versions.

        If specified along with version 'latest', a prerelease will be selected
        if it is the most recent available version.

        Sorting assumes prereleases are named appropriately
        (e.g. alpha < beta < rc).

    .PARAMETER Import
        If specified, imports the module into the global scope after installation.

        Deprecated. Use PSDependAction = 'Import' instead. This parameter may be
        removed in a future release.

    .PARAMETER PSDependAction
        Test, Install, or Import the module.
        Defaults to Install.

        Test:    Returns $true or $false depending on whether the dependency is present
        Install: Installs the dependency
        Import:  Imports the dependency

    .EXAMPLE
        @{
            BuildHelpers = @{
                DependencyType = 'PSResourceGet'
                Version        = 'latest'
            }
            InvokeBuild = @{
                DependencyType = 'PSResourceGet'
                Version        = '3.2.1'
            }
        }

        # Install the latest BuildHelpers and version 3.2.1 of InvokeBuild from PSGallery.
        # Omitting Version, or setting it to '', also resolves to latest.

    .EXAMPLE
        @{
            BuildHelpers = @{
                DependencyType = 'PSResourceGet'
                Target         = 'C:\Build'
            }
        }

        # Save the latest BuildHelpers module from PSGallery to C:\Build
        # (i.e. C:\Build\BuildHelpers will be the module folder)

    .EXAMPLE
        @{
            BuildHelpers = @{
                DependencyType = 'PSResourceGet'
                Parameters     = @{
                    Repository = 'PSPrivateGallery'
                }
            }
        }

        # Install the latest BuildHelpers from a registered private repository.
        # Register the repository first with Register-PSResourceRepository.
        #
        # Examples of private repositories include:
        # - Artifactory
        # - ProGet
        # - GitLab Package Registry

    .EXAMPLE
        @{
            'vmware.powercli' = @{
                DependencyType = 'PSResourceGet'
                Parameters     = @{
                    Prerelease = $true
                }
            }
        }

        # Install the latest version of PowerCLI, allowing prerelease versions.
#>

[CmdletBinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [AllowNull()]
    [string]$Repository = 'PSGallery',

    [switch]$NoClobber,

    [switch]$AcceptLicense,

    [switch]$Prerelease,

    [switch]$Import,

    [ValidateSet('Test', 'Install', 'Import')]
    [string[]]$PSDependAction = @('Install')
)

if (-not (Get-Command -Name Install-PSResource -ErrorAction SilentlyContinue)) {
    Write-Error "PSResourceGet (Microsoft.PowerShell.PSResourceGet) is required but not available. Install it before using the PSResourceGet dependency type."
    return
}

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

# Target doubles as Scope: AllUsers/CurrentUser = install scope; any other value = filesystem path
if (-not $Dependency.Target) {
    $Scope = 'CurrentUser'
}
else {
    $Scope = $Dependency.Target
}

$Credential = $Dependency.Credential

if ('AllUsers', 'CurrentUser' -notcontains $Scope) {
    $command = 'save'
}
else {
    $command = 'install'
}

Write-Verbose -Message "Getting dependency [$Name] from PowerShell repository [$Repository]"

if ($Repository) {
    $validRepo = Get-PSResourceRepository -Name $Repository -Verbose:$false -ErrorAction SilentlyContinue
    if (-not $validRepo) {
        $repoRegistry = $Dependency.PSDependOptions.Repositories
        if (-not $repoRegistry -or -not $repoRegistry.ContainsKey($Repository)) {
            Write-Error "[$Repository] is not registered and no URL was found in PSDependOptions.Repositories. Add an entry to register it automatically."
            return
        }
        $repoUrl = $repoRegistry[$Repository]
        if ($repoUrl -isnot [string]) {
            Write-Error "PSDependOptions.Repositories entry for [$Repository] must be a string URL for PSResourceGet dependencies."
            return
        }
        $registerSplat = @{
            Name    = $Repository
            Uri     = $repoUrl
            Trusted = $true
        }
        if ($Credential) { $registerSplat.Credential = $Credential }
        Write-Verbose "Registering PSResource repository [$Repository] at [$repoUrl]"
        Register-PSResourceRepository @registerSplat
    } elseif ($Dependency.PSDependOptions.Repositories -and $Dependency.PSDependOptions.Repositories.ContainsKey($Repository)) {
        $declaredUrl = $Dependency.PSDependOptions.Repositories[$Repository]
        if ($declaredUrl -is [string] -and $validRepo.Uri -ne $declaredUrl) {
            Write-Warning "Repository [$Repository] is already registered at [$($validRepo.Uri)] but PSDependOptions.Repositories declares [$declaredUrl]. Using existing registration."
        }
    }
}

# TrustRepository defaults to $true so unattended / CI installs do not hang on a trust prompt
$params = @{
    Name            = $Name
    TrustRepository = $true
}

if ($PSBoundParameters.ContainsKey('NoClobber')) {
    $params.Add('NoClobber', $NoClobber)
}

if ($PSBoundParameters.ContainsKey('Prerelease')) {
    $params.Add('Prerelease', $Prerelease)
}

if ($PSBoundParameters.ContainsKey('AcceptLicense')) {
    $params.Add('AcceptLicense', $AcceptLicense)
}

if ($Repository) {
    $params.Add('Repository', $Repository)
}

if ($Version -and $Version -ne 'latest') {
    $params.Add('Version', $Version)
}

if ($Credential) {
    $params.Add('Credential', $Credential)
}

if ($command -eq 'save') {
    $ModuleName = Join-Path $Scope $Name
}
elseif ($command -eq 'install') {
    $ModuleName = $Name
}

# Filter params to only those accepted by the target command
$targetCmd = if ($command -eq 'save') {
    'Save-PSResource'
}
else {
    'Install-PSResource'
}
$availableParameters = (Get-Command $targetCmd).Parameters
$tempParams = $params.Clone()
foreach ($thisParameter in $params.Keys) {
    if (-not $availableParameters.ContainsKey($thisParameter)) {
        Write-Verbose -Message "Removing parameter [$thisParameter] from [$targetCmd] as it is not available"
        $tempParams.Remove($thisParameter)
    }
}
$params = $tempParams.Clone()

Add-ToPsModulePathIfRequired -Dependency $Dependency -Action $PSDependAction

$Existing = Get-Module -ListAvailable -Name $ModuleName -ErrorAction SilentlyContinue

if ($Existing) {
    Write-Verbose "Found existing module [$Name]"
    # Thanks to Brandon Padgett!
    $ExistingVersion = $Existing | Measure-Object -Property Version -Maximum | Select-Object -ExpandProperty Maximum
    $FindModuleParams = @{ Name = $Name }
    if ($Repository) {
        $FindModuleParams.Add('Repository', $Repository)
    }
    if ($Credential) {
        $FindModuleParams.Add('Credential', $Credential)
    }
    if ($Prerelease) {
        $FindModuleParams.Add('Prerelease', $true)
    }

    # Version string, and that version is already installed (may not be the maximum)
    $matchedExisting = if ($Version -and $Version -ne 'latest') {
        $Existing | Where-Object {
            Test-VersionEquality -ReferenceVersion $_.Version -DifferenceVersion $Version
        } | Select-Object -First 1
    }
    if ($matchedExisting) {
        Write-Verbose "You have the requested version [$Version] of [$Name]"
        Import-PSDependModule -Name $ModuleName -Action $PSDependAction -Version $matchedExisting.Version

        if ($PSDependAction -contains 'Test') {
            return $true
        }
        return $null
    }

    $GalleryVersion = Find-PSResource @FindModuleParams | Measure-Object -Property Version -Maximum | Select-Object -ExpandProperty Maximum
    # Compare using SemanticVersion first (PSResourceGet uses SemVer); fall back to System.Version
    [System.Version]$parsedVersion = $null
    [System.Version]$parsedGalleryVersion = $null
    [System.Management.Automation.SemanticVersion]$parsedSemanticVersion = $null
    [System.Management.Automation.SemanticVersion]$parsedTempSemanticVersion = $null
    $existingIsUpToDate = if (
        [System.Management.Automation.SemanticVersion]::TryParse([string]$ExistingVersion, [ref]$parsedSemanticVersion) -and
        [System.Management.Automation.SemanticVersion]::TryParse([string]$GalleryVersion, [ref]$parsedTempSemanticVersion)
    ) {
        $parsedTempSemanticVersion -le $parsedSemanticVersion
    }
    elseif (
        [System.Version]::TryParse([string]$ExistingVersion, [ref]$parsedVersion) -and
        [System.Version]::TryParse([string]$GalleryVersion, [ref]$parsedGalleryVersion)
    ) {
        $parsedGalleryVersion -le $parsedVersion
    }
    else {
        $false
    }

    # latest, and we have latest
    if ($Version -and ($Version -eq 'latest' -or $Version -eq '') -and $existingIsUpToDate) {
        Write-Verbose "You have the latest version of [$Name], with installed version [$ExistingVersion] and repository version [$GalleryVersion]"
        Import-PSDependModule -Name $ModuleName -Action $PSDependAction -Version $ExistingVersion

        if ($PSDependAction -contains 'Test') {
            return $true
        }
        return $null
    }
    Write-Verbose "Continuing to install [$Name]: Requested version [$Version], existing version [$ExistingVersion]"
}

# No dependency found, return false if we're testing alone...
if ($PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1) {
    return $false
}

if ($PSDependAction -contains 'Install') {
    if ('AllUsers', 'CurrentUser' -contains $Scope) {
        Write-Verbose "Installing [$Name] with scope [$Scope]"
        Install-PSResource @params -Scope $Scope
    }
    else {
        Write-Verbose "Saving [$Name] to path [$Scope]"
        Write-Verbose "Creating directory path to [$Scope]"
        if (-not (Test-Path $Scope -ErrorAction SilentlyContinue)) {
            $null = New-Item -ItemType Directory -Path $Scope -Force -ErrorAction SilentlyContinue
        }
        Save-PSResource @params -Path $Scope
    }
}

# Conditional import — params['Version'] may be a NuGet range; resolve to a concrete installed version
$importVs = $params['Version']
if ($importVs -and $importVs -match '[\[\](,]') {
    $importVs = Get-Module -ListAvailable -Name $ModuleName -ErrorAction SilentlyContinue |
        Measure-Object -Property Version -Maximum |
        Select-Object -ExpandProperty Maximum
}
Import-PSDependModule -Name $ModuleName -Action $PSDependAction -Version $importVs
