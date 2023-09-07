function Import-PSDependModule {
    [cmdletbinding()]
    param (
        [string[]]$Name = $ModulePath,
        $Action = $PSDependAction,
        [string] $Version
    )
    if($PSDependAction -contains 'Import')
    {
        foreach($Mod in $Name)
        {
            Write-Verbose "Importing [$Mod]"
            $importParams = @{
                Name = $Mod
                Scope = 'Global'
                Force = $true
            }
            if ($Version -and $Version -ne 'latest') {
                # Sanitize version string. The RequiredVersion parameter is a System.Version and
                # doesn't know anything about pre-release tags.
                $BaseVersion = ($Version -split '-')[0]
                $importParams.add('RequiredVersion',$BaseVersion)
            }
            Import-Module @importParams
        }
    }
}
