function Update-PSDependLock {
    <#
    .SYNOPSIS
        Resolve a DependencyFile's full dependency graph and write a lock file

    .DESCRIPTION
        Resolve a DependencyFile's full dependency graph and write a lock file

        Works like npm's package-lock.json: every dependency whose DependencyType
        supports the Resolve action is resolved to the highest version that
        satisfies its Version (exact, 'latest', or a NuGet range), its own
        dependencies are resolved the same way recursively, and the result is
        written next to the DependencyFile as <name>.lock.json
        (requirements.psd1 -> requirements.lock.json).

        A package required by several dependencies is locked to one version that
        satisfies all of their constraints; conflicting constraints fail the update.

        Once a lock exists, Invoke-PSDepend and Get-Dependency use it automatically:
        each dependency installs at its locked version and locked transitive
        packages install first. If the DependencyFile changes, the lock is reported
        as out of date until you run Update-PSDependLock again (or pass -IgnoreLock).

        DependencyTypes without a Resolve action (Git, GitHub, FileDownload, ...) are
        recorded in the lock so drift is detected, but install exactly as before.

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
