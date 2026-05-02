[cmdletbinding(DefaultParameterSetName = 'Task')]
param(
    [parameter(ParameterSetName = 'Task', Position = 0)]
    [string[]]$Task = 'default',

    # Install build dependencies from requirements.psd1 via PSDepend
    [switch]$Bootstrap,

    [parameter(ParameterSetName = 'Help')]
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Bootstrap.IsPresent) {
    Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    if (-not (Get-Module -Name PSDepend -ListAvailable)) {
        Install-Module -Name PSDepend -Repository PSGallery -Scope CurrentUser -Force
    }
    Import-Module -Name PSDepend -Verbose:$false
    Invoke-PSDepend -Path './requirements.psd1' -Install -Import -Force -WarningAction SilentlyContinue
}

if ($PSCmdlet.ParameterSetName -eq 'Help') {
    Get-PSakeScriptTasks -buildFile './psakeFile.ps1' | Format-Table -Property Name, Description
} else {
    Set-BuildEnvironment -Force
    Invoke-psake -buildFile './psakeFile.ps1' -taskList $Task -Verbose:$VerbosePreference
    exit ([int](-not $psake.build_success))
}
