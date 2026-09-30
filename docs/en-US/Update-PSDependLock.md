---
external help file: PSDepend-help.xml
Module Name: PSDepend
online version: https://github.com/PowerShellOrg/PSDepend
schema: 2.0.0
---

# Update-PSDependLock

## SYNOPSIS

Resolve a dependency file's full dependency graph and write a lock file.

## SYNTAX

```
Update-PSDependLock [[-Path] <String[]>] [-Recurse <Boolean>] [-PSDependTypePath <String>]
 [-Credentials <Hashtable>] [-PassThru] [-WhatIf] [-Confirm] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION

Works like npm's package-lock.json. Every dependency whose type supports the `Resolve` action
(`PSGalleryModule`, `PSResourceGet`, `PSGalleryNuget`, `Nuget`, `Chocolatey`, `Npm`) is resolved to the
highest version that satisfies its Version (exact, `latest`, or a NuGet range); its own dependencies are
resolved the same way recursively, and the result is written next to the dependency file as
`<name>.lock.json` (`requirements.psd1` -> `requirements.lock.json`).

A package required by several dependencies is locked to one version that satisfies all of their
constraints; conflicting constraints fail the update. `Npm` pins only the declared package and leaves
its subtree to npm's own package-lock.json.

Once a lock exists, `Invoke-PSDepend` and `Get-Dependency` use it automatically: each dependency
installs at its locked version and locked transitive packages install first. If the dependency file
changes, the lock is reported as out of date until you run `Update-PSDependLock` again (or pass
`-IgnoreLock`). Dependency types without a `Resolve` action are recorded in the lock so drift is
detected, but install exactly as declared.

## EXAMPLES

### Example 1

```powershell
Update-PSDependLock -Path .\requirements.psd1
```

Resolves every dependency (and their dependencies) in requirements.psd1 and writes requirements.lock.json.

### Example 2

```powershell
Update-PSDependLock -Path C:\Project -Recurse $false -PassThru
```

Writes a lock for each *.depend.psd1 and requirements.psd1 directly under C:\Project and returns their paths.

## PARAMETERS

### -Path

Path to a specific depend.psd1 file, or to a folder that is searched for *.depend.psd1 and
requirements.psd1 files. Defaults to the current path.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 0
Default value: .
Accept pipeline input: True (ByValue, ByPropertyName)
Accept wildcard characters: False
```

### -Recurse

If Path is a folder, whether to search it recursively. Defaults to $true.

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: True
Accept pipeline input: False
Accept wildcard characters: False
```

### -PSDependTypePath

Path to a PSDependMap.psd1 file. Defaults to the one in the PSDepend module root.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credentials

Hashtable of PSCredentials keyed by the `Credential` name used in the dependency file, for
dependencies served from private feeds.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru

Return the path of each lock file that was written.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf

Shows what would happen if the cmdlet runs. The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction

{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String[]

## OUTPUTS

### System.String

The lock file path, when -PassThru is specified.

## NOTES

## RELATED LINKS

[Invoke-PSDepend](Invoke-PSDepend.md)

[Get-Dependency](Get-Dependency.md)
