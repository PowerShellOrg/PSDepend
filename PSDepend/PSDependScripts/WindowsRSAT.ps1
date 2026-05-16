<#
    .SYNOPSIS
        'Install a WindowsRSAT PowerShell module using Add-WindowsCapability or Install-WindowsFeature, depending on OS'

    .DESCRIPTION
        Installs a RSAT Module in Windows.

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
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

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
    'BitsTransfer'              = @{
        'WindowsFeature' = 'RSAT-Bits-Server'
        #'WindowsCapability' = 'Rsat.BitLocker.Recovery.Tools'
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
        'WindowsCapability' = 'rsat.dns.tools'
    }
    'DNSServer'                 = @{
        'WindowsFeature'    = 'RSAT-DNS-Server'
        'WindowsCapability' = 'rsat.dns.tools'
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
        'WindowsFeature'    = 'RSAT'
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
    
    if (-not ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
        throw "Must be an admin to install RSAT modules"
    }

    #Server
    $Type = 'WindowsFeature'
    if ((get-CimInstance -ClassName Win32_OperatingSystem).ProductType -eq 1) {
        # Workstation
        $Type = 'WindowsCapability'
    }
    
    if ($null -eq $RSAT_MODULE_MAP[$ModuleName][$type]) {        
        throw "Unknown Module $ModuleName"
    }
    
    if ($Type -eq 'WindowsFeature') {
        $null = install-windowsfeature -name $RSAT_MODULE_MAP[$ModuleName][$Type]
    }
    else {
        $null = Add-WindowsCapability -Online -Name $RSAT_MODULE_MAP[$ModuleName][$Type]
    }
}

# Conditional import
Import-PSDependModule -Name $ModuleName -Action $PSDependAction