---
external help file: PSDepend-help.xml
Module Name: PSDepend
online version: https://github.com/PowerShellOrg/PSDepend
schema: 2.0.0
---

# Get-Dependency

## SYNOPSIS

Read a dependency psd1 file.

## SYNTAX

### File (Default)
```
Get-Dependency [-Path <String[]>] [-Tags <String[]>] [-Recurse] [-Credentials <Hashtable>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Hashtable
```
Get-Dependency [-Tags <String[]>] [-InputObject <Hashtable[]>] [-Credentials <Hashtable>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION

Reads a PSDepend dependency file (.psd1) and returns structured dependency objects.

## EXAMPLES

### Example 1

```powershell
Get-Dependency -Path .\requirements.psd1
```

Returns all dependencies defined in requirements.psd1.

### Example 2

```powershell
Get-Dependency -Path . -Recurse -Tags 'prod'
```

Recursively finds all dependency files under the current directory and returns dependencies tagged 'prod'.

## PARAMETERS

### -Path

Path to project root or a specific dependency file.

```yaml
Type: String[]
Parameter Sets: File
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Tags

Limit results to dependencies with one or more matching tags.

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

### -Recurse

Search recursively for dependency files under Path.

```yaml
Type: SwitchParameter
Parameter Sets: File
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputObject

Treat a hashtable as dependency file contents rather than reading from disk.

```yaml
Type: Hashtable[]
Parameter Sets: Hashtable
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credentials

Hashtable of PSCredentials keyed by credential name for private feeds.

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

### System.Collections.Hashtable[]

## OUTPUTS

### PSDepend.Dependency

## NOTES

## RELATED LINKS

[Invoke-PSDepend](Invoke-PSDepend.md)
