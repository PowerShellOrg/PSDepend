Properties {
    # PSDepend stages files without compiling to a single PSM1
    $PSBPreference.Build.CompileModule = $false

    # Help generation
    $PSBPreference.Help.DefaultLocale = 'en-US'

    # Extra subdirectories beyond Public/Private that must be staged
    $PSBPreference.Build.CopyDirectories = @('PSDependScripts', 'en-US')

    # Test configuration
    $PSBPreference.Help.DefaultLocale = 'en-US'
    $PSBPreference.Test.OutputFile = 'out/testResults.xml'
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
}

# Pre-set before -FromModule so PowerShellBuild 0.7.x's null-check doesn't override it.
# Skips BuildHelp (GenerateMarkdown) — doc generation is not needed in the test pipeline
# and Build-PSBuildMarkdown has a Remove-Module scope bug specific to PSDepend.
$PSBBuildDependency = @('StageFiles')

Task Default -Depends Test

# PowerShellBuild adds the following tasks:
# - Init
# - Clean
# - StageFiles
# - Build
# - Test
# - BuildHelp
# - GenerateMarkdown
# - Publish
Task Test -FromModule PowerShellBuild -MinimumVersion '0.7.3'
