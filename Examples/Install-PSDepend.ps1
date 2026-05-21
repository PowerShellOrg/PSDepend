# No PowerShellGallery? Run this to install PSDepend.
# Downloads nuget to your ~\ home directory
# Creates $Path (and full path to it)
# Downloads module to $Path\PSDepend
# Copies nuget.exe to $Path\PSDepend (skips bootstrap on initial PSDepend import)

# Example: .\Install-PSDepend -Path C:\Modules (Installs to C:\Modules\PSDepend)
param( [string]$Path ) # Parent folder PSDepend is installed to. Defaults to Profile\WindowsPowerShell\Modules and creates dir if needed

if (-not $Path) { $Path = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Modules' }

# Bootstrap nuget if we don't have it
if (-not ($NugetPath = (Get-Command 'nuget.exe' -ErrorAction SilentlyContinue).Path)) {
    $NugetPath = Join-Path $ENV:USERPROFILE nuget.exe
    if (-not (Test-Path $NugetPath)) { Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile $NugetPath }
}

# Bootstrap PSDepend, re-use nuget.exe for the module
if ($path) { $null = New-Item $path -ItemType Directory -Force }
$NugetParams = 'install', 'PSDepend', '-Source', 'https://www.powershellgallery.com/api/v2/',
'-ExcludeVersion', '-NonInteractive', '-OutputDirectory', $Path
& $NugetPath @NugetParams
Move-Item -Path $NugetPath -Destination "$(Join-Path $Path PSDepend)\nuget.exe" -Force
