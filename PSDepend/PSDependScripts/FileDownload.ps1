<#
    .SYNOPSIS
        Download a file

    .DESCRIPTION
        Download a file

        Relevant Dependency metadata:
            DependencyName (Key): The key for this dependency is used as the URL. This can be overridden by 'Source'
            Name: Optional file name for the downloaded file.  Defaults to parsing filename from the URL
            Target: The folder to download this file to.  If a full path to a new file is used, this overrides any other file name.
            Source: Optional override for URL
            AddToPath: If specified, prepend the target's parent container to PATH

    .PARAMETER PSDependAction
        Test or Install the module.  Defaults to Install

        Test: Return true or false on whether the dependency is in place
        Install: Install the dependency

    .EXAMPLE
        sqllite_dll = @{
            DependencyType = 'FileDownload'
            Source = 'https://github.com/RamblingCookieMonster/PSSQLite/blob/main/PSSQLite/x64/System.Data.SQLite.dll?raw=true'
            Target = 'C:\temp'
        }

        # Downloads System.Data.SQLite.dll to C:\temp

    .EXAMPLE
        'https://github.com/RamblingCookieMonster/PSSQLite/blob/main/PSSQLite/x64/System.Data.SQLite.dll?raw=true' = @{
            DependencyType = 'FileDownload'
            Target = 'C:\temp\sqlite.dll'
        }

        # Downloads System.Data.SQLite.dll to C:\temp\sqlite.dll
#>
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]
    $Dependency,

    [ValidateSet('Test', 'Install')]
    [string[]]$PSDependAction = @('Install')
)

function Parse-URLForFile {
    [cmdletbinding()]
    param($URL)
    # This will need work.  Assume leaf is file.  If CGI exists in leaf, assume it is after the file
    $FileName = $URL.split('/')[-1]
    if ($FileName -match '\?') {
        $FileName.split('?')[0]
    }
    else {
        $FileName
    }
    Write-Verbose "Parsed file name [$FileName] from `$URL"
}

# Extract data from Dependency
$DependencyName = $Dependency.DependencyName
$Name = $Dependency.Name
$Target = $Dependency.Target
$Source = $Dependency.Source

# Pick the URL
if ($Source) {
    $URL = $Source
}
else {
    $URL = $DependencyName
}
Write-Verbose "Using URL: $URL"

# Act on target path....
$ToInstall = $False # Anti pattern

# Normalize relative paths against $PWD so callers don't get burned by cwd-dependent splits
if (-not [IO.Path]::IsPathRooted($Target)) {
    $Target = Join-Path $PWD $Target
}

$TargetParent = Split-Path $Target -Parent
$PathToAdd = $Target

if (Test-Path $Target -PathType Leaf) {
    # File exists.  We should download to temp spot, compare hashes, take action as appropriate.
    # For now, skip the file.
    Write-Verbose "Skipping existing file [$Target]"
    if ($PSDependAction -contains 'Test') {
        return $True
    }
    $PathToAdd = Split-Path $Target -Parent
}
elseif ([IO.Path]::GetExtension($Target) -and -not (Test-Path $Target -PathType Container)) {
    # Target has a file extension — treat as a full destination file path
    if (-not (Test-Path $TargetParent)) {
        Write-Error "Could not find parent path [$TargetParent] for target [$Target]"
        if ($PSDependAction -contains 'Test') {
            return $False
        }
    }
    else {
        $Path = $Target
        $ToInstall = $True
        Write-Verbose "Target has extension, treating as file path [$Target]"
    }
}
else {
    # No extension (or already a container) — treat target as a directory
    Write-Verbose "[$Target] is a container, creating path to file"
    if (-not (Test-Path $Target)) {
        New-Item -ItemType Directory -Path $Target -Force | Out-Null
    }
    If ($Name) {
        # explicit name
        $FileName = $Name
    }
    else {
        $FileName = Parse-URLForFile -URL $URL
    }
    $Path = Join-Path $Target $FileName

    if (Test-Path $Path -PathType Leaf) {
        Write-Verbose "Skipping existing file [$Path]"
        if ($PSDependAction -contains 'Test') {
            return $True
        }
    }
    else {
        $ToInstall = $True
    }
}
Write-Verbose "Using [$Path] as `$Target"

#No dependency found, return false if we're testing alone...
if ( $PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1) {
    return $False
}
Write-Verbose "Downloading [$URL] to [$Path]"

if ($PSDependAction -contains 'Install' -and $ToInstall) {
    # Future considerations:
    # Should we check for existing? And if we find it, still download file, and compare sha256 hash, replace if it does not match?
    # We should consider credentials at some point, but PSD1 does not lend itself to securely storing passwords
    Get-WebFile -URL $URL -Path $Path
}

if ($Dependency.AddToPath) {
    Write-Verbose "Setting PATH to`n$($PathToAdd, $env:PATH -join [IO.Path]::PathSeparator | Out-String)"
    Add-ToItemCollection -Reference Env:\Path -Item $PathToAdd
}
