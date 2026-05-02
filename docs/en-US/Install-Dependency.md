---
external help file: PSDepend-help.xml
Module Name: PSDepend
online version: https://github.com/PowerShellOrg/PSDepend
schema: 2.0.0
---

# Install-Dependency

## SYNOPSIS

Install a specific dependency.

## SYNTAX

```
Install-Dependency [-Dependency] <PSObject[]> [[-PSDependTypePath] <String>] [-Tags <String[]>]
 [-Force] [<CommonParameters>]
```

## DESCRIPTION

Installs a dependency object returned by Get-Dependency, using the dependency type's
Install action.

## EXAMPLES

### Example 1

```powershell
Get-Dependency -Path .\requirements.psd1 | Install-Dependency
```

Installs all dependencies defined in requirements.psd1.

### Example 2

```powershell
Get-Dependency -Path .\requirements.psd1 | Install-Dependency -Force
```

Installs all dependencies, bypassing prompts.

## PARAMETERS

### -Dependency

A PSDepend.Dependency object from Get-Dependency.

```yaml
Type: PSObject[]
Parameter Sets: (All)
Aliases:
Required: True
Position: 0
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
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Tags

Only install dependencies with the specified tags.

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

### -Force

Force installation, skipping interactive prompts.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable,
-Verbose, -WarningAction, and -WarningVariable.

## INPUTS

### PSDepend.Dependency

## OUTPUTS

## NOTES

## RELATED LINKS

[Get-Dependency](Get-Dependency.md)
[Import-Dependency](Import-Dependency.md)
[Invoke-PSDepend](Invoke-PSDepend.md)
