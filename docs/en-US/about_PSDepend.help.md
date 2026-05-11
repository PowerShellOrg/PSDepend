# about_PSDepend

## SHORT DESCRIPTION

PSDepend is a PowerShell dependency handler that installs, imports, and tests
dependencies defined in .psd1 files.

## LONG DESCRIPTION

PSDepend reads dependency files (.psd1) and processes each dependency using a
pluggable set of dependency type scripts. Out of the box it supports:

- **PSGalleryModule** — Install modules from the PowerShell Gallery
- **PSGalleryNuget** — Install modules from the Gallery without PowerShellGet
- **Git** — Clone Git repositories
- **GitHub** — Download and extract GitHub archives
- **Chocolatey** — Install Chocolatey packages (Windows only)
- **FileDownload** — Download arbitrary files (Windows only)
- **FileSystem** — Copy files or folders (Windows only)
- **Npm** — Install Node.js packages
- **DotnetSdk** — Install the .NET SDK
- **Command** — Run an arbitrary PowerShell command
- **Package** — Install via PackageManagement
- **Task** — Run simple task dependencies
- **Noop** — Display parameters (useful for testing/validation)

### Dependency File Format

A dependency file is a PowerShell data file (.psd1) containing a hashtable. The
simplest form uses the key as the dependency name and the value as the version:

```powershell
@{
    Pester           = '5.6.1'
    PSScriptAnalyzer = 'latest'
}
```

For more control, specify the dependency type and additional properties:

```powershell
@{
    MyModule = @{
        DependencyType = 'PSGalleryModule'
        Version        = '1.0.0'
        Tags           = 'prod'
        Target         = 'C:\Modules'
    }
}
```

### PSDependOptions

Use the special `PSDependOptions` key to set defaults for all dependencies in
the file:

```powershell
@{
    PSDependOptions = @{
        Target    = 'CurrentUser'
        AddToPath = $true
    }

    Pester = 'latest'
}
```

## EXAMPLES

### Install dependencies from a file

```powershell
Invoke-PSDepend -Path .\requirements.psd1 -Force
```

### Test whether dependencies are satisfied

```powershell
Invoke-PSDepend -Path .\requirements.psd1 -Test -Quiet
```

### Install and immediately import

```powershell
Invoke-PSDepend -Path .\requirements.psd1 -Install -Import -Force
```

## NOTE

Custom dependency types can be registered by adding entries to a custom
PSDependMap.psd1 and passing its path via `-PSDependTypePath`.

## SEE ALSO

- [Invoke-PSDepend](Invoke-PSDepend.md)
- [Get-PSDependType](Get-PSDependType.md)
- PSDepend project: https://github.com/PowerShellOrg/PSDepend
