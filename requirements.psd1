@{
    PSDependOptions  = @{
        AddToPath = $true
        Target    = 'CurrentUser'
    }

    psake            = 'latest'
    PowerShellBuild  = 'latest'
    Pester           = 'latest'
    PSScriptAnalyzer = 'latest'
    PSDeploy         = 'latest'
    BuildHelpers     = 'latest'
}
