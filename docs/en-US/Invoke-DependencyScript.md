---
external help file: PSDepend-help.xml
Module Name: PSDepend
online version: https://github.com/PowerShellOrg/PSDepend
schema: 2.0.0
---

# Invoke-DependencyScript

## SYNOPSIS

Invoke a dependency type script for a given action.

## SYNTAX

```
Invoke-DependencyScript -Dependency <PSObject> [-PSDependTypePath <String>] [-PSDependAction <String[]>]
 [-Tags <String[]>] [-Quiet] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION

Low-level function that invokes the script for a specific dependency type and action
(Test, Install, or Import). Typically called by Invoke-PSDepend rather than directly.

## EXAMPLES

### Example 1

```powershell
Get-Dependency -Path .\requirements.psd1 | Invoke-DependencyScript -PSDependAction Test
```

Tests each dependency in requirements.psd1.

## PARAMETERS

### -Dependency

A PSDepend.Dependency object from Get-Dependency.

```yaml
Type: PSObject
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

### -PSDependAction

The action to invoke: Test, Install, or Import.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Install
Accept pipeline input: False
Accept wildcard characters: False
```

### -Tags

Only invoke dependencies with the specified tags.

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

### -Quiet

Return $true or $false for Test actions instead of detailed output.

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
