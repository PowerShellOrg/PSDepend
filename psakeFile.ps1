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

# Override with: .\build.ps1 InstallLocal -Properties @{PreReleaseLabel='rc1'}
Task InstallLocal -Depends StageFiles {
    $label = if ($PreReleaseLabel) { $PreReleaseLabel } else { "pre-$(git rev-parse --short HEAD)" }

    $moduleName   = $PSBPreference.General.ModuleName
    $stagedDir    = $PSBPreference.Build.ModuleOutDir
    $manifestPath = Join-Path $stagedDir "$moduleName.psd1"
    $version      = (Import-PowerShellDataFile $manifestPath).ModuleVersion

    Update-Metadata -Path $manifestPath -PropertyName Prerelease -Value $label

    $destRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules\PSDepend'
    $destDir  = Join-Path $destRoot "$version-$label"

    if (Test-Path $destDir) {
        Remove-Item $destDir -Recurse -Force
    }
    Copy-Item -Path $stagedDir -Destination $destDir -Recurse
    Write-Host "Installed PSDepend $version-$label -> $destDir"
}

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
