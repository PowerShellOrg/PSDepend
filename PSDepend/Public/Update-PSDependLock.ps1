function Update-PSDependLock {
    <#
    .SYNOPSIS
        Resolve a DependencyFile's full dependency graph and write a lock file.

    .DESCRIPTION
        Resolve a DependencyFile's full dependency graph and write a lock file

        Works like npm's package-lock.json: every dependency whose DependencyType
        supports Resolve is resolved to the highest version satisfying Version,
        and its dependencies are resolved recursively. Gallery, NuGet and
        Chocolatey types accept NuGet ranges; Npm accepts npm semver ranges.

        One version is locked per DependencyType::Name. Resolution is greedy:
        child constraints are intersected, but PSDepend does not backtrack to an
        older parent version. Narrow a parent range when an older version is
        required. Incompatible constraints fail the update.

        The result is written next to the DependencyFile as <name>.lock.json
        (requirements.psd1 -> requirements.lock.json). Invoke-PSDepend and
        Get-Dependency then use it automatically. A changed Dependency, Version,
        resolution Source, or DependencyScript parameter makes the lock stale.

        DependencyTypes without Resolve (Git, GitHub, FileDownload, ...) are
        recorded for drift detection but install exactly as declared. Lock files
        should be committed and reviewed like code; format version 1 validates
        exact versions but does not contain package content hashes.

        See Get-Help about_PSDepend for more information.

    .PARAMETER Path
        Path to a specific depend.psd1 file, or to a folder that we recursively search for *.depend.psd1 and requirements.psd1 files

        Defaults to the current path

    .PARAMETER Recurse
        If path is a folder, whether to recursively search for *.depend.psd1 and requirements.psd1 files under that folder

        Defaults to $True

    .PARAMETER PSDependTypePath
        Specify a PSDependMap.psd1 file that maps DependencyTypes to their scripts.

        This defaults to the PSDependMap.psd1 in the PSDepend module folder

    .PARAMETER Credentials
        Specifies a hashtable of PSCredentials to use for each dependency that is served from a private feed. The key of the hashtable must match the Credential property value in the dependency.

    .PARAMETER PassThru
        Return the path of each lock file that was written

    .EXAMPLE
        Update-PSDependLock -Path .\requirements.psd1

        # Resolve every dependency (and their dependencies) in requirements.psd1 and write requirements.lock.json

    .EXAMPLE
        Update-PSDependLock -Path C:\Project -Recurse $false

        # Write a lock for each *.depend.psd1 and requirements.psd1 directly under C:\Project

    .LINK
        https://github.com/PowerShellOrg/PSDepend
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [OutputType([string])]
    param(
        [validatescript( { Test-Path -Path $_ -ErrorAction Stop })]
        [parameter( Position = 0,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True)]
        [string[]]$Path = '.',

        [bool]$Recurse = $True,

        [validatescript( { Test-Path -Path $_ -PathType Leaf -ErrorAction Stop })]
        [string]$PSDependTypePath = $(Join-Path $ModuleRoot PSDependMap.psd1),

        [hashtable]$Credentials,

        [switch]$PassThru
    )
    process {
        foreach ($PathItem in $Path) {
            $DependencyFiles = @( Resolve-DependScripts -Path $PathItem -Recurse $Recurse )
            if ($DependencyFiles.Count -eq 0) {
                Write-Warning "No *.depend.psd1 or requirements.psd1 files found under [$PathItem]"
                continue
            }

            foreach ($DependencyFile in $DependencyFiles) {
                $GetParams = @{ Path = $DependencyFile; IgnoreLock = $true }
                if ($null -ne $Credentials) {
                    $GetParams.Add('Credentials', $Credentials)
                }
                $Dependencies = @( Get-Dependency @GetParams -ErrorAction Stop | Where-Object { $_ } )
                $LockPath = Get-PSDependLockPath -DependencyFile $DependencyFile

                Write-Verbose "Resolving [$($Dependencies.Count)] dependencies from [$DependencyFile]"
                $Lock = Resolve-PSDependLock -Dependency $Dependencies -PSDependTypePath $PSDependTypePath

                if ($PSCmdlet.ShouldProcess($LockPath, "Write lock for '$DependencyFile'")) {
                    Export-PSDependLock -Lock $Lock -Path $LockPath
                    Write-Verbose "Wrote lock with [$($Lock.packages.Count)] packages to [$LockPath]"
                    if ($PassThru) {
                        $LockPath
                    }
                }
            }
        }
    }
}
