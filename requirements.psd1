@{
    PSDependOptions = @{
        Target = 'CurrentUser'
    }
    'psake' = @{
        Version = '4.9.1'
    }
    'PowerShellBuild' = @{
        Version = '0.7.3'
    }
    'Pester' = @{
        Version    = '6.1.0'
        Parameters = @{
            SkipPublisherCheck = $true
        }
    }
    'PSScriptAnalyzer' = @{
        Version = '1.19.1'
    }
    'BuildHelpers' = @{
        Version = '2.0.16'
    }
}
