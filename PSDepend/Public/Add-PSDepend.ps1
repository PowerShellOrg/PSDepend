function Add-PSDepend {
    <#
    .SYNOPSIS
        Add a dependency to a DependencyFile.

    .DESCRIPTION
        Add a dependency to a DependencyFile.

        Add-PSDepend parses the target DependencyFile with the PowerShell AST
        and splices the new entry in as text, leaving every other entry and
        any comments byte-for-byte untouched; the file's existing encoding
        (including BOM) and newline style are also preserved. By default it
        then re-locks the file with Update-PSDependLock, so the
        DependencyFile and its requirements.lock.json never drift apart; if
        the lock step fails, the DependencyFile edit is rolled back. Use
        -NoLock to skip that step for offline or CI use.

        Add-PSDepend only declares the dependency; it does not install it.
        Run Invoke-PSDepend afterward to install.

        New entries are written as the terse 'Name' = 'Version' form when only
        Name and Version were given and the DependencyType resolves to
        PSGalleryModule (the only type the terse form can round-trip through
        Get-Dependency's shorthand parsing); any other field, or any other
        DependencyType, writes the full hashtable form instead. The psd1 key
        is always the bare Name: a dependency of a different DependencyType
        but the same Name is treated as a collision like any other.

        See Get-Help about_PSDepend for more information.

    .PARAMETER Name
        Name of the dependency. Becomes the DependencyName: the psd1 key.
        Entries Add-PSDepend writes never include a separate Name field, so
        dependency scripts that need a package or repo name (and fall back to
        DependencyName when Name is absent) read it from this key.

    .PARAMETER Version
        Version (or NuGet-style range) for the dependency.

        Defaults to 'latest'.

    .PARAMETER DependencyType
        Type of dependency. See Get-PSDependType.

        If not specified, defaults to the target file's PSDependOptions.DependencyType
        if one is set, then to GitHub or Git if Name looks like 'owner/repo' or
        contains a '/', and finally to PSGalleryModule.

    .PARAMETER Source
        Source for this dependency. Usage depends on the DependencyType.

    .PARAMETER Target
        Target for this dependency. Usage depends on the DependencyType.

    .PARAMETER Tags
        One or more tags to categorize or filter this dependency.

    .PARAMETER Parameters
        A hashtable of parameters to splat to the DependencyType's script.

    .PARAMETER DependsOn
        DependencyName that must run before this one.

    .PARAMETER PreScripts
        One or more paths to PowerShell scripts to run before this dependency.

    .PARAMETER PostScripts
        One or more paths to PowerShell scripts to run after this dependency.

    .PARAMETER AddToPath
        Prepend the resulting folder to $ENV:Path and $ENV:PSModulePath.

    .PARAMETER Credential
        Name of a credential. Must match a key in the hashtable later passed
        to Invoke-PSDepend's or Update-PSDependLock's -Credentials parameter.

    .PARAMETER Path
        A DependencyFile, a new DependencyFile to create, or a directory to
        search for one.

        Defaults to the current path. If Path is a directory, it is searched
        for *.depend.psd1 and requirements.psd1 files: exactly one match is
        used as-is, no matches falls back to creating <Path>\requirements.psd1,
        and more than one match is an error asking you to narrow it with -Path.

    .PARAMETER Recurse
        If Path is a directory, whether to recursively search it for
        *.depend.psd1 and requirements.psd1 files.

        Defaults to $True.

    .PARAMETER PSDependTypePath
        Specify a PSDependMap.psd1 file that maps DependencyTypes to their scripts.

        This defaults to the PSDependMap.psd1 in the PSDepend module folder

    .PARAMETER Credentials
        Specifies a hashtable of PSCredentials to use for each dependency that
        is served from a private feed, for the Update-PSDependLock step this
        command runs by default. The key of the hashtable must match the
        Credential property value in the dependency. Ignored with -NoLock.

    .PARAMETER Force
        If a dependency with this Name already exists in the DependencyFile,
        overwrite it. The existing entry is fully replaced: any field not
        passed this time is dropped, not carried over.

    .PARAMETER NoLock
        Skip the Update-PSDependLock step after writing the DependencyFile.
        The lock, if one exists, is left stale.

    .PARAMETER PassThru
        Return the path of the DependencyFile that was written.

    .EXAMPLE
        Add-PSDepend psake latest

        # Add 'psake' = 'latest' to .\requirements.psd1, creating it if needed,
        # then update its lock

    .EXAMPLE
        Add-PSDepend -DependencyType GitHub -Name 'RamblingCookieMonster/PowerShell' -Version main

        # Add a GitHub dependency in full hashtable form

    .EXAMPLE
        Add-PSDepend Pester 5.9.0 -Parameters @{ SkipPublisherCheck = $true } -Force

        # Overwrite the existing 'Pester' entry, replacing it entirely

    .EXAMPLE
        Add-PSDepend psake latest -Path .\requirements.psd1 -NoLock -WhatIf

        # Preview the change without touching disk or re-locking

    .LINK
        https://github.com/PowerShellOrg/PSDepend
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingPlainTextForPassword',
        '',
        Justification = 'Credential is the name of a credential key to look up in -Credentials, not a credential or password itself; matches the DependencyFile schema''s own Credential field.'
    )]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUsePSCredentialType',
        '',
        Justification = 'Credential is the name of a credential key to look up in -Credentials, not a credential or password itself; matches the DependencyFile schema''s own Credential field.'
    )]
    [CmdletBinding(SupportsShouldProcess = $True)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Position = 1)]
        [string]$Version = 'latest',

        [string]$DependencyType,

        [string]$Source,

        [string]$Target,

        [string[]]$Tags,

        [hashtable]$Parameters,

        [string[]]$DependsOn,

        [string[]]$PreScripts,

        [string[]]$PostScripts,

        [switch]$AddToPath,

        [string]$Credential,

        [string]$Path = '.',

        [bool]$Recurse = $True,

        [validatescript( { Test-Path -Path $_ -PathType Leaf -ErrorAction Stop })]
        [string]$PSDependTypePath = $(Join-Path $ModuleRoot PSDependMap.psd1),

        [hashtable]$Credentials,

        [switch]$Force,

        [switch]$NoLock,

        [switch]$PassThru
    )
    process {
        if ($Name -ieq 'PSDependOptions') {
            throw "'PSDependOptions' is reserved and cannot be used as a dependency Name"
        }

        $DependencyFile = Resolve-PSDependFileTarget -Path $Path -Recurse $Recurse
        $FileExisted = Test-Path -LiteralPath $DependencyFile -PathType Leaf
        $NoBomUtf8 = [System.Text.UTF8Encoding]::new($false)

        if ($FileExisted) {
            # detectEncodingFromByteOrderMarks: if the file has a BOM, CurrentEncoding
            # reflects it; if not, it falls back to $NoBomUtf8, so round-tripping
            # through $FileEncoding preserves the file's original encoding either way.
            $Reader = [System.IO.StreamReader]::new($DependencyFile, $NoBomUtf8, $true)
            try {
                $OriginalFileText = $Reader.ReadToEnd()
                $FileEncoding = $Reader.CurrentEncoding
            }
            finally {
                $Reader.Dispose()
            }
        }
        else {
            $OriginalFileText = $null
            $FileEncoding = $NoBomUtf8
        }

        if ([string]::IsNullOrWhiteSpace($OriginalFileText)) {
            $ExistingData = @{}
            $FileText = "@{`r`n}`r`n"
        }
        else {
            $Base = Split-Path -Path $DependencyFile -Parent
            $Leaf = Split-Path -Path $DependencyFile -Leaf
            $ExistingData = Import-LocalizedData -BaseDirectory $Base -FileName $Leaf
            $FileText = $OriginalFileText
        }

        $NewlineStyle = if ($FileText -match "`r`n") { "`r`n" } elseif ($FileText -match "`n") { "`n" } else { "`r`n" }

        $ExistingKey = $null
        foreach ($Key in $ExistingData.Keys) {
            if ($Key -ine 'PSDependOptions' -and $Key -ieq $Name) {
                $ExistingKey = $Key
                break
            }
        }
        if ($ExistingKey -and -not $Force) {
            throw "Dependency '$Name' already exists in '$DependencyFile'. Use -Force to overwrite it."
        }

        $EffectiveType =
        if ($PSBoundParameters.ContainsKey('DependencyType')) {
            $DependencyType
        }
        elseif ($ExistingData.PSDependOptions -and $ExistingData.PSDependOptions.DependencyType) {
            $ExistingData.PSDependOptions.DependencyType
        }
        elseif ($Name -match '/' -and @($Name -split '/').Count -eq 2) {
            'GitHub'
        }
        elseif ($Name -match '/') {
            'Git'
        }
        else {
            'PSGalleryModule'
        }

        $KnownTypes = @(Get-PSDependType -Path $PSDependTypePath -SkipHelp | Select-Object -ExpandProperty DependencyType)
        if ($EffectiveType -notin $KnownTypes) {
            throw "DependencyType '$EffectiveType' is not defined in '$PSDependTypePath'. Known types: $($KnownTypes -join ', ')"
        }

        $ExtraFieldNames = 'DependencyType', 'Source', 'Target', 'Tags', 'Parameters', 'DependsOn', 'PreScripts', 'PostScripts', 'AddToPath', 'Credential'
        $HasExtraFields = @($ExtraFieldNames | Where-Object { $PSBoundParameters.ContainsKey($_) }).Count -gt 0
        $UseTerseForm = -not $HasExtraFields -and $EffectiveType -eq 'PSGalleryModule'

        if ($UseTerseForm) {
            $EntryKeyValueText = "'$($Name -replace "'", "''")' = '$($Version -replace "'", "''")'"
        }
        else {
            $Fields = [ordered]@{
                DependencyType = $EffectiveType
                Version        = $Version
            }
            if ($PSBoundParameters.ContainsKey('Source')) { $Fields.Source = $Source }
            if ($PSBoundParameters.ContainsKey('Target')) { $Fields.Target = $Target }
            if ($PSBoundParameters.ContainsKey('Tags')) { $Fields.Tags = $Tags }
            if ($PSBoundParameters.ContainsKey('DependsOn')) { $Fields.DependsOn = $DependsOn }
            if ($PSBoundParameters.ContainsKey('PreScripts')) { $Fields.PreScripts = $PreScripts }
            if ($PSBoundParameters.ContainsKey('PostScripts')) { $Fields.PostScripts = $PostScripts }
            if ($AddToPath) { $Fields.AddToPath = $true }
            if ($PSBoundParameters.ContainsKey('Credential')) { $Fields.Credential = $Credential }
            if ($PSBoundParameters.ContainsKey('Parameters')) { $Fields.Parameters = $Parameters }

            $FieldLines = foreach ($FieldName in $Fields.Keys) {
                "        $FieldName = $(ConvertTo-PSDependLiteral -Value $Fields[$FieldName] -IndentLevel 2)"
            }
            $EntryKeyValueText = "'$($Name -replace "'", "''")' = @{`r`n$($FieldLines -join "`r`n")`r`n    }"
        }

        $tokens = $null
        $parseErrors = $null
        $Ast = [System.Management.Automation.Language.Parser]::ParseInput($FileText, [ref]$tokens, [ref]$parseErrors)
        if ($parseErrors) {
            throw "DependencyFile '$DependencyFile' has a syntax error and cannot be edited automatically: $($parseErrors[0].Message)"
        }
        $Pipeline = $Ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.PipelineAst] } | Select-Object -First 1
        $HashtableAst = if ($Pipeline) { $Pipeline.PipelineElements[0].Expression }
        if ($HashtableAst -isnot [System.Management.Automation.Language.HashtableAst]) {
            throw "DependencyFile '$DependencyFile' must contain a single hashtable literal (@{ ... }) at the top level"
        }

        $EntryKeyValueText = $EntryKeyValueText -replace "`r`n", $NewlineStyle

        if ($ExistingKey) {
            $Match = $HashtableAst.KeyValuePairs | Where-Object { $_.Item1.Value -ieq $Name } | Select-Object -First 1
            $NewText = $FileText.Substring(0, $Match.Item1.Extent.StartOffset) + $EntryKeyValueText + $FileText.Substring($Match.Item2.Extent.EndOffset)
        }
        else {
            $InsertPos = $HashtableAst.Extent.EndOffset - 1
            $Before = $FileText.Substring(0, $InsertPos)
            $After = $FileText.Substring($InsertPos)
            $Separator = if ($Before.Length -eq 0 -or $Before.EndsWith($NewlineStyle)) { '' } else { $NewlineStyle }
            $NewText = $Before + $Separator + "    $EntryKeyValueText" + $NewlineStyle + $After
        }

        if (-not $PSCmdlet.ShouldProcess($DependencyFile, "Add dependency '$Name'")) {
            return
        }

        $ParentDir = Split-Path -Path $DependencyFile -Parent
        if ($ParentDir -and -not (Test-Path -LiteralPath $ParentDir)) {
            $null = New-Item -ItemType Directory -Path $ParentDir -Force
        }
        # .NET WriteAllText throws on failure (unlike Set-Content's non-terminating
        # errors), so a failed write never falls through into the lock step below.
        [System.IO.File]::WriteAllText($DependencyFile, $NewText, $FileEncoding)

        if (-not $NoLock) {
            try {
                $LockParams = @{
                    Path             = $DependencyFile
                    PSDependTypePath = $PSDependTypePath
                }
                if ($null -ne $Credentials) {
                    $LockParams.Credentials = $Credentials
                }
                $null = Update-PSDependLock @LockParams -Confirm:$false
            }
            catch {
                if ($FileExisted) {
                    [System.IO.File]::WriteAllText($DependencyFile, $OriginalFileText, $FileEncoding)
                }
                else {
                    Remove-Item -LiteralPath $DependencyFile -Force -ErrorAction SilentlyContinue
                }
                throw "Added '$Name' to '$DependencyFile' but failed to update its lock, so the edit was rolled back: $_"
            }
        }

        if ($PassThru) {
            $DependencyFile
        }
    }
}
