---
external help file: PSDepend-help.xml
Module Name: PSDepend
online version: https://github.com/PowerShellOrg/PSDepend
schema: 2.0.0
---

# Get-PSDependType

## SYNOPSIS

Get dependency types and related information.

## SYNTAX

```
Get-PSDependType [[-DependencyType] <String>] [[-Path] <String>] [-ShowHelp] [-SkipHelp]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION

Returns information about registered PSDepend dependency types, optionally showing the
help content for each type's script.

## EXAMPLES

### Example 1

```powershell
Get-PSDependType
```

Returns all registered dependency types.

### Example 2

```powershell
Get-PSDependType -DependencyType PSGalleryModule -ShowHelp
```

Returns the PSGalleryModule dependency type and displays its help.

## PARAMETERS

### -DependencyType

Limit results to this dependency type. Accepts wildcards.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Path

Path to a PSDependMap.psd1 file. Defaults to the one in the PSDepend module root.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowHelp

Display help content for the dependency type script.

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

### -SkipHelp

Skip retrieving help content for dependency type scripts.

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

## OUTPUTS

## NOTES

## RELATED LINKS
