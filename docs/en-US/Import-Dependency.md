---
external help file: PSDepend-help.xml
Module Name: PSDepend
online version: https://github.com/PowerShellOrg/PSDepend
schema: 2.0.0
---

# Import-Dependency

## SYNOPSIS

Import a specific dependency.

## SYNTAX

```
Import-Dependency -Dependency <PSObject[]> [-PSDependTypePath <String>] [-Tags <String[]>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION

Imports a dependency object returned by Get-Dependency, using the dependency type's
Import action.

## EXAMPLES

### Example 1

```powershell
Get-Dependency -Path .\requirements.psd1 | Import-Dependency
```

Imports all dependencies defined in requirements.psd1.

## PARAMETERS

### -Dependency

A PSDepend.Dependency object from Get-Dependency.

```yaml
Type: PSObject[]
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
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

### -Tags

Only import dependencies with the specified tags.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

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

### PSDepend.Dependency

## OUTPUTS

## NOTES

## RELATED LINKS
