---
external help file: PSDepend-help.xml
Module Name: PSDepend
online version: https://github.com/PowerShellOrg/PSDepend
schema: 2.0.0
---

# Invoke-PSDepend

## SYNOPSIS

Install, import, or test dependencies defined in a PSDepend file.

## SYNTAX

```
Invoke-PSDepend [[-Path] <String[]>] [[-InputObject] <Hashtable[]>] [[-PSDependTypePath] <String>]
 [-Tags <String[]>] [-Recurse] [-Test] [-Quiet] [-Import] [-Install] [-Force] [-Target <String>]
 [-Credentials <Hashtable>] [<CommonParameters>]
```

## DESCRIPTION

The primary entry point for PSDepend. Reads a dependency file (or hashtable) and installs,
imports, or tests each dependency using the appropriate dependency type script.

By default, Invoke-PSDepend installs dependencies. Use -Test to check whether dependencies
are already present, or -Import to import them after installation.

## EXAMPLES

### Example 1

```powershell
Invoke-PSDepend -Path .\requirements.psd1
```

Installs all dependencies in requirements.psd1.

### Example 2

```powershell
Invoke-PSDepend -Path .\requirements.psd1 -Test -Quiet
```

Returns $true if all dependencies are satisfied, $false otherwise.

### Example 3

```powershell
Invoke-PSDepend -Path .\requirements.psd1 -Tags 'CI' -Force
```

Installs only dependencies tagged 'CI', bypassing prompts.

### Example 4

```powershell
Invoke-PSDepend -Path . -Recurse -Import
```

Recursively finds all dependency files under the current directory and imports them.

## PARAMETERS

### -Path

Path to a dependency file or folder. Defaults to the current directory.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:
Required: False
Position: 0
Default value: .
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputObject

Treat a hashtable as dependency file contents rather than reading from disk.

```yaml
Type: Hashtable[]
Parameter Sets: (All)
Aliases:
Required: False
Position: 1
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
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Tags

Only process dependencies with the specified tags.

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

Recursively search for dependency files under Path.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:
Required: False
Position: Named
Default value: True
Accept pipeline input: False
Accept wildcard characters: False
```

### -Test

Test whether dependencies are already satisfied instead of installing.

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

### -Quiet

When used with -Test, return $true or $false instead of detailed objects.

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

### -Import

Import dependencies after installation, if supported by the dependency type.

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

### -Install

Run the install action. This is the default behavior.

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

### -Force

Force dependency installation, skipping interactive prompts.

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

### -Target

Override the Target property for all dependencies.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable,
-Verbose, -WarningAction, and -WarningVariable.

## INPUTS

### System.Collections.Hashtable[]

## OUTPUTS

## NOTES

## RELATED LINKS

[Get-Dependency](Get-Dependency.md)
[Install-Dependency](Install-Dependency.md)
[Import-Dependency](Import-Dependency.md)
[Test-Dependency](Test-Dependency.md)
