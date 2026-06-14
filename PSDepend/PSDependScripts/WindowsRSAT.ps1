# cspell:ignore ADCS ADRMS DFSN DFSR DISM FSRM GPMC Mgmt RSAT VAMT
<#
    .SYNOPSIS
        'Install a WindowsRSAT PowerShell module using Add-WindowsCapability or Install-WindowsFeature, depending on OS'

    .DESCRIPTION
        Installs a RSAT Module in Windows.

        The Install action requires an elevated (administrator) session, on both
        Workstation (Add-WindowsCapability) and Server (Install-WindowsFeature).
        The Test action does not require elevation. If the module is already
        present, all actions short-circuit and succeed without elevation.

        Relevant Dependency metadata:
            Name: The name for the module to install

    .PARAMETER PSDependAction
        Test, Install, or Import the module.  Defaults to Install

        Test: Return true or false on whether the dependency is in place
        Install: Install the dependency
        Import: Import the dependency

    .EXAMPLE
        @{
            ActiveDirectory = @{
                DependencyType = 'WindowsRSAT'
                Name = 'ActiveDirectory'
            }
        }
#>
[CmdletBinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [PSObject[]]$Dependency,

    [ValidateSet('Test', 'Install', 'Import')]
    [string[]]$PSDependAction = @('Install')
)


$RSAT_MODULE_MAP = @{
    'ActiveDirectory'           = @{
        'WindowsFeature'    = 'RSAT-AD-Powershell'
        'WindowsCapability' = 'Rsat.ActiveDirectory.DS-LDS.Tools'
    }
    'ADDSDeployment'            = @{
        'WindowsFeature'    = 'RSAT-AD-Powershell'
        'WindowsCapability' = 'Rsat.ActiveDirectory.DS-LDS.Tools'
    }
    'ADCSAdministration'        = @{
        'WindowsFeature'    = 'RSAT-ADCS-Mgmt'
        'WindowsCapability' = 'Rsat.CertificateServices.Tools'
    }
    'ADCSDeployment'            = @{
        'WindowsFeature'    = 'RSAT-ADCS-Mgmt'
        'WindowsCapability' = 'Rsat.CertificateServices.Tools'
    }
    'ADRMS'                     = @{
        'WindowsFeature' = 'RSAT-ADRMS'
        #'WindowsCapability' = 'Rsat.CertificateServices.Tools'
    }
    'ADRMSAdmin'                = @{
        'WindowsFeature' = 'RSAT-ADRMS'
        #'WindowsCapability' = 'Rsat.CertificateServices.Tools'
    }
    'BitLocker'                 = @{
        'WindowsFeature'    = 'RSAT-Feature-Tools-BitLocker-RemoteAdminTool'
        'WindowsCapability' = 'Rsat.BitLocker.Recovery.Tools'
    }
    'DFSN'                      = @{
        'WindowsFeature' = 'RSAT-DFS-Mgmt-Con'
        #'WindowsCapability' = 'Rsat.BitLocker.Recovery.Tools'
    }
    'DFSR'                      = @{
        'WindowsFeature' = 'RSAT-DFS-Mgmt-Con'
        #'WindowsCapability' = 'Rsat.BitLocker.Recovery.Tools'
    }
    'DHCP'                      = @{
        'WindowsFeature'    = 'RSAT-DHCP'
        'WindowsCapability' = 'Rsat.DHCP.Tools'
    }
    'DNSClient'                 = @{
        'WindowsFeature'    = 'RSAT-DNS-Server'
        'WindowsCapability' = 'Rsat.Dns.Tools'
    }
    'DNSServer'                 = @{
        'WindowsFeature'    = 'RSAT-DNS-Server'
        'WindowsCapability' = 'Rsat.Dns.Tools'
    }
    'FailoverClusters'          = @{
        'WindowsFeature'    = 'RSAT-Clustering-PowerShell'
        'WindowsCapability' = 'Rsat.FailoverCluster.Management.Tools'
    }
    'FileServerResourceManager' = @{
        'WindowsFeature' = 'RSAT-FSRM-Mgmt'
        #'WindowsCapability' = 'Rsat.FileServices.Tools'
    }
    'GroupPolicy'               = @{
        'WindowsFeature'    = 'GPMC'
        'WindowsCapability' = 'Rsat.GroupPolicy.Management.Tools'
    }
    'Hyper-V'                   = @{
        'WindowsFeature' = 'RSAT-Hyper-V-Tools'
        #'WindowsCapability' = 'Rsat.GroupPolicy.Management.Tools'
    }
    'IISAdministration'         = @{
        'WindowsFeature' = 'web-mgmt-console'
        #'WindowsCapability' = 'Rsat.GroupPolicy.Management.Tools'
    }
    'RemoteAccess'              = @{
        'WindowsFeature'    = 'RSAT-RemoteAccess-Powershell'
        'WindowsCapability' = 'Rsat.RemoteAccess.Management.Tools'
    }
    'VAMT'                      = @{
        'WindowsFeature'    = 'RSAT-VA-Tools'
        'WindowsCapability' = 'Rsat.VolumeActivation.Tools'
    }
}

# Extract data from Dependency
$ModuleName = $Dependency.Name
if (-not $ModuleName) {
    $ModuleName = $Dependency.DependencyName
}

if (Get-Module -ListAvailable -Name $ModuleName -ErrorAction SilentlyContinue) {
    Write-Verbose "Found existing module [$ModuleName]"
    if ($PSDependAction -contains 'Test') {
        return $True
    }
    return $null
}

#No dependency found, return false if we're testing alone...
if ( $PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1) {
    return $False
}

if ($PSDependAction -contains 'Install') {

    if (-not (Test-Administrator)) {
        throw "Installing RSAT module '$ModuleName' requires an elevated session. Re-run from a PowerShell started with 'Run as administrator'."
    }

    #Server
    $Type = 'WindowsFeature'
    if ((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -eq 1) {
        # Workstation
        $Type = 'WindowsCapability'
    }

    if (-not $RSAT_MODULE_MAP.ContainsKey($ModuleName)) {
        throw "Unknown module '$ModuleName'. No RSAT mapping is defined for it."
    }

    $mapping = $RSAT_MODULE_MAP[$ModuleName]
    if (-not $mapping.ContainsKey($Type) -or [string]::IsNullOrEmpty($mapping[$Type])) {
        # In the table, but no entry for this OS install path. Most commonly a
        # module that ships only as a Server feature (e.g. Hyper-V, ADRMS) and
        # has no equivalent Windows capability on a Workstation.
        throw "Module '$ModuleName' is not available via $Type on this system (it may be server-only)."
    }

    if ($Type -eq 'WindowsFeature') {
        $null = Install-WindowsFeature -Name $mapping[$Type]
    }
    else {
        # Resolve the exact capability identity (e.g.
        # 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0') from the stable short
        # name in the map. DISM does accept the short base name directly, but
        # that relies on undocumented prefix matching and the version suffix
        # varies by Windows build -- so look it up and pass the canonical name.
        $capabilityName = $mapping[$Type]
        $capability = Get-WindowsCapability -Online -Name "$capabilityName*" | Select-Object -First 1
        if (-not $capability) {
            throw "No Windows capability matching '$capabilityName' was found on this system."
        }
        $null = Add-WindowsCapability -Online -Name $capability.Name
    }
}

# Conditional import
Import-PSDependModule -Name $ModuleName -Action $PSDependAction
