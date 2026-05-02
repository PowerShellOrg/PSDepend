properties {
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

    # Exclude Windows-only tests on non-Windows runners
    if (-not $IsWindows) {
        $PSBPreference.Test.ExcludeTagFilter = @('WindowsOnly')
    }

    # Publish configuration — API key injected via environment in CI
    $PSBPreference.Publish.PSRepository        = 'PSGallery'
    $PSBPreference.Publish.PSRepositoryApiKey  = $env:PSGALLERY_API_KEY
}

task default -depends Test

task Init    -FromModule PowerShellBuild -minimumVersion '0.6.1'
task Clean   -FromModule PowerShellBuild -minimumVersion '0.6.1'
task Build   -FromModule PowerShellBuild -minimumVersion '0.6.1'
task Analyze -FromModule PowerShellBuild -minimumVersion '0.6.1'
task Pester  -FromModule PowerShellBuild -minimumVersion '0.6.1'
task Test    -FromModule PowerShellBuild -minimumVersion '0.6.1'
task Publish -FromModule PowerShellBuild -minimumVersion '0.6.1'
