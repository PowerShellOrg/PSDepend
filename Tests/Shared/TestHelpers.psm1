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
        [pscredential]$Credential,
        [switch]$AddToPath
    )

    [pscustomobject]@{
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
    [CmdletBinding()]
    param(
        [string]$UserName = 'testUser',
        [string]$Password = 'testPassword'
    )

    [pscredential]::new($UserName, (ConvertTo-SecureString $Password -AsPlainText -Force))
}

Export-ModuleMember -Function New-PSDependFixture, New-TestCredential
