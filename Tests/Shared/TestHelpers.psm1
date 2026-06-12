function New-PSDependFixture {
    [CmdletBinding()]
    param(
        [string]$DependencyName = 'TestModule',
        [string]$DependencyType = 'PSGalleryModule',
        [AllowNull()][object]$Name = $null,
        [AllowNull()][object]$Version = $null,
        [AllowNull()][object]$Target = $null,
        [AllowNull()][object]$Source = $null,
        [hashtable]$Parameters = @{},
        [PSCredential]$Credential,
        [switch]$AddToPath
    )

    [PSCustomObject]@{
        PSTypeName     = 'PSDepend.Dependency'
        DependencyFile = $null
        DependencyName = $DependencyName
        DependencyType = $DependencyType
        Name           = $Name
        Version        = $Version
        Parameters     = $Parameters
        Source         = $Source
        Target         = $Target
        AddToPath      = [bool]$AddToPath
        Tags           = @()
        DependsOn      = $null
        PreScripts     = $null
        PostScripts    = $null
        Credential     = $Credential
        Raw            = @{}
    }
}

function New-TestCredential {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingPlainTextForPassword',
        '',
        Justification = 'Dummy credential for testing.'
    )]
    [CmdletBinding()]
    [OutputType([PSCredential])]
    param(
        [string]$UserName = 'testUser',
        [string]$Password = 'testPassword'
    )

    [PSCredential]::new(
        $UserName,
        (ConvertTo-SecureString $Password -AsPlainText -Force)
    )
}

function Test-PSDependTypeSupportedHere {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][string]$DependencyType,
        [string]$MapPath = (
            # Use Path::Combine because Join-Path was stupid long
            [System.IO.Path]::Combine(
                $PSScriptRoot,
                '..',
                '..',
                'PSDepend',
                'PSDependMap.psd1'
            )
        )
    )

    $map = Import-PowerShellDataFile -Path $MapPath
    if (-not $map.ContainsKey($DependencyType)) {
        return $false
    }
    $support = @($map[$DependencyType].Supports)

    if ($PSVersionTable.PSEdition -eq 'Core') {
        $windowsCoreOk = $IsWindows -and ($support -contains 'windows')
        if (-not $windowsCoreOk -and $support -notcontains 'core') {
            return $false
        }
    } elseif ($support -notcontains 'windows') {
        return $false
    }

    if ($IsLinux  -and $support -notcontains 'linux') {
        return $false
    }
    if ($IsMacOS  -and $support -notcontains 'macos') {
        return $false
    }
    if ($IsWindows -and $support -notcontains 'windows') {
        return $false
    }
    $true
}

Export-ModuleMember -Function New-PSDependFixture, New-TestCredential, Test-PSDependTypeSupportedHere
