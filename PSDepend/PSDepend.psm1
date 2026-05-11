#Get public and private function definition files.
    $Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
    $Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )
    $ModuleRoot = $PSScriptRoot

#Dot source the files
    Foreach($import in @($Public + $Private))
    {
        Try
        {
            . $import.fullname
        }
        Catch
        {
            Write-Error -Message "Failed to import function $($import.fullname): $_"
        }
    }

#Get nuget dependecy file if we don't have it
    Get-Content $ModuleRoot\PSDepend.Config |
        Where-Object {$_ -and $_ -notmatch "^\s*#"} |
        Foreach-Object {
            $Name = ( $_ -split '=')[0].trim()
            $Value = ( $_ -split '=')[1].trim()
            # Revisit later and only apply these for '*path', if we have other types of variables...
            $Value = $Value -replace '\$ModuleRoot', $ModuleRoot
            $Value = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Value)
            Set-Variable -Name $Name -Value $Value
        }
    if(Test-PlatformSupport -Support 'windows','core') {
        BootStrap-Nuget -NugetPath $NuGetPath
    }

Export-ModuleMember -Function $Public.Basename
