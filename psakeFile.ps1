Properties {
    # PSDepend stages files without compiling to a single PSM1
    $PSBPreference.Build.CompileModule = $false

    # Help generation
    $PSBPreference.Help.DefaultLocale = 'en-US'

    # Extra subdirectories beyond Public/Private that must be staged
    $PSBPreference.Build.CopyDirectories = @('PSDependScripts', 'en-US')

    # Test configuration
    $PSBPreference.Test.OutputFile                              = './Output/testResults.xml'
    $PSBPreference.Test.OutputFormat                            = 'JUnitXml'
    $PSBPreference.Test.ScriptAnalysis.Enabled                  = $true
    $PSBPreference.Test.ScriptAnalysis.FailBuildOnSeverityLevel = 'Error'
    $PSBPreference.Test.CodeCoverage.Enabled                    = $false
    # Explicit casing required for Linux (case-sensitive filesystem)
    $PSBPreference.Test.RootDir                                 = Join-Path $ENV:BHProjectPath 'Tests'

    # Exclude Windows-only tests on non-Windows runners
    if (-not $IsWindows) {
        $PSBPreference.Test.ExcludeTagFilter = @('WindowsOnly')
    }

    # Publish configuration — API key injected via environment in CI
    $PSBPreference.Publish.PSRepository        = 'PSGallery'
    $PSBPreference.Publish.PSRepositoryApiKey  = $env:PSGALLERY_API_KEY
}

Task Default -Depends Test

Task Test -FromModule PowerShellBuild -MinimumVersion '0.6.1'
