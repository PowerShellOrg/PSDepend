<#
    .SYNOPSIS
        EXPERIMENTAL: Use Robocopy or Copy-Item for folder and file dependencies, respectively.

    .DESCRIPTION
        EXPERIMENTAL: Use Robocopy or Copy-Item for folder and file dependencies, respectively.

        Runs in the current session (i.e. as the current user)

        Relevant Dependency metadata:
            DependencyName (Key): The key for this dependency is used as the URL. This can be overridden by 'Source'
            Name: Optional file name for the downloaded file.  Defaults to parsing filename from the URL
            Target: The folder to copy the source to.  If the source is a file, we adjust this in Robocopy to append the source folder name.
            Source: The source folder or file to copy

    .PARAMETER Dependency
        Dependency to run

    .PARAMETER PSDependAction
        Test, Install, or Import the module.  Defaults to Install

        Test: Return true or false on whether the dependency is in place
              IMPORTANT: If a folder exists, return $True, whether the contents are the same or not
                         If a file exists, we check the hash
        Install: Install the dependency
        Import: Import the dependency 'Target'.  Override with ImportPath

    .PARAMETER ImportPath
        If specified with PSDependAction Import, we import this path, instead of the target (or target parent if target is a file)

    .PARAMETER Force
        If specified, and target is a folder, overwrite the target

    .PARAMETER Mirror
        If specified and the target is a folder, we effectively call robocopy /MIR (Can remove folders/files...)

    .EXAMPLE

        @{
            'notepad' = @{
                DependencyType = 'FileSystem'
                Source = 'C:\windows\notepad.exe'
                Target = 'C:\PSDependPesterTest'
            }
        }

        # Copy C:\Windows\Notepad.exe to C:\PSDependPesterTest\notepad.exe

    .EXAMPLE

        @{
            'psams' = @{
                DependencyType = 'FileSystem'
                Source = '\\FileServer\powershell\modules\psams'
                Target = 'C:\ProjectX'
            }
        }

        # Copy psams module to C:\ProjectX\psams

#>
[cmdletbinding()]
param (
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]
    $Dependency,

    [ValidateSet('Test', 'Install', 'Import')]
    [string[]]$PSDependAction = @('Install'),

    [string]$ImportPath,

    [switch]$Force,

    [switch]$Mirror
)

# Extract data from Dependency
$DependencyName = $Dependency.DependencyName
$Name = $Dependency.Name
$Target = $Dependency.Target
$Sources = @($Dependency.Source)

$TestOutput = @()
foreach ($Source in @($Sources)) {
    if (-not (Test-Path $Source)) {
        if ($PSDependAction -notcontains 'Test') {
            Write-Error "Skipping $DependencyName, could not find source [$Source]"
        }
        continue
    }
    $IsContainer = ( Get-Item $Source ).PSIsContainer

    # Resolve PSDrives.
    $Target = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Target)
    $Source = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Source)

    if ($IsContainer) {
        $Folder = Split-Path $Source -Leaf
        $Target = Join-Path $Target $Folder
        if (-not $ImportPath) { $ImportPath = $Target }
        # We don't test equality for containers yet
        if (Test-Path $Target) {
            $TestOutput += $true
        }
        else {
            $TestOutput += $false
        }
        if ($PSDependAction -contains 'Install') {
            # TODO: Add non Windows equivalent...
            [string[]]$Arguments = "/E"
            if (-not ($Dependency.Parameters.Force -eq $True -or $Force)) {
                # Without -Force, skip files where the target copy is newer
                $Arguments += "/XO"
            }
            if ($Dependency.Parameters.Mirror -eq $True -or $Mirror) {
                $Arguments += "/PURGE"
            }

            Write-Verbose "Invoking ROBOCOPY.exe $Source $Target $Arguments"
            ROBOCOPY.exe $Source $Target @Arguments
        }
    }
    else {
        $SourceFolderPath = Split-Path $Source -Parent
        $SourceFileName = Split-Path $Source -Leaf
        $TargetFile = Join-Path $Target $SourceFileName
        $SourceHash = ( Get-Hash $Source ).SHA256
        $TargetHash = $null
        if (Test-Path $Target -PathType Leaf) {
            $TargetHash = ( Get-Hash $Target -ErrorAction SilentlyContinue -WarningAction SilentlyContinue ).SHA256
            $TargetPath = $Target
        }
        elseif (Test-Path $TargetFile -PathType Leaf) {
            $TargetHash = ( Get-Hash $TargetFile -ErrorAction SilentlyContinue -WarningAction SilentlyContinue ).SHA256
            $TargetPath = $TargetFile
        }
        Write-Verbose "Source [$Source] hash [$SourceHash]`n`tTarget [$TargetPath] hash [$TargetHash]"

        if ($TargetHash -ne $SourceHash) {
            Write-Verbose "Hashes do not match"
            if ($PSDependAction -contains 'Install') {
                Write-Verbose "Copying file [$Source] to [$Target]"
                Copy-Item -Path $Source -Destination $Target -Force
            }
            if ($PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1) {
                $TestOutput += $false
            }
        }
        else {
            Write-Verbose "Matching hash: [$Source] = [$TargetFile]"
            if ($PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1) {
                $TestOutput += $True
            }
        }
    }
}

if ($PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1) {
    if (@($TestOutput) -contains $false -or @($TestOutput) -notcontains $true) {
        return $false
    }
    else {
        return $True
    }
}

if ($PSDependAction -contains 'Import') {
    if (-not $ImportPath) {
        if (Test-Path $Target -PathType Leaf) {
            $ImportPath = Split-Path $Target -Parent
        }
        elseif (Test-Path $Target -PathType Container) {
            $ImportPath = $Target
        }
        else {
            Write-Error "Could not import target [$Target], path not found"
            return
        }
    }
    Import-PSDependModule $ImportPath
}
