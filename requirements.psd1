@{
    PSDependOptions = @{
        Target = 'CurrentUser'
    }
    'psake' = @{
        Version = '4.9.1'
    }
    'PowerShellBuild' = @{
        Version = '0.7.2'
    }
    'Pester' = @{
        Version    = '5.7.1'
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
