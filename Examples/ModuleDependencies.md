# Handling Module Dependencies

`Install-Module` handles dependencies declared in a module manifest's `RequiredModules` section, but it only covers the PowerShell Gallery. PSDepend lets you declare dependencies from multiple sources — Gallery modules, Git repos, and file downloads — in one place.

This walkthrough demonstrates embedding a `requirements.psd1` in a module so dependencies are resolved automatically on import.

## Set Up the Demo Module

```powershell
mkdir C:\MyModule -Force

New-ModuleManifest -Path C:\MyModule\MyModule.psd1 `
                   -RootModule 'MyModule.psm1' `
                   -FunctionsToExport Test-PSDependExample `
                   -CmdletsToExport $null `
                   -VariablesToExport $null `
                   -AliasesToExport $null

Set-Content -Path C:\MyModule\MyModule.psm1 @'
# Resolve dependencies on module load
Invoke-PSDepend -Path $PSScriptRoot\Requirements.psd1 -Target $PSScriptRoot\Dependencies -Install -Force

Import-Module Posh-SSH

Function Test-PSDependExample {
    Get-ChildItem $PSScriptRoot\Dependencies -Recurse -Depth 1 | Select-Object -ExpandProperty FullName
    Get-Module | Select-Object Name, Path
}
'@

Set-Content C:\MyModule\Requirements.psd1 -Value @'
@{
    PSDependOptions = @{
        Target = '$DependencyFolder\Dependencies'
        Parameters = @{
            Force = $True
        }
    }

    'Posh-SSH' = 'latest'

    'PowerShellOrg/PSDepend' = 'master'

    'AzCopy_Download' = @{
        Name = 'azcopy.msi'
        DependencyType = 'FileDownload'
        Source = 'http://aka.ms/downloadazcopy'
        DependsOn = 'Posh-SSH'
    }

    'AzCopy_Install' = @{
        DependencyType = 'Command'
        Source = '$DepFolder = "$DependencyFolder\Dependencies"',
                 'if(-not (Test-Path $DepFolder\AzCopy\AzCopy.exe)){
                      $null = New-Item $DepFolder\AzCopy -ItemType Directory -Force;
                      Start-Process msiexec -ArgumentList "/a $DepFolder\azcopy.msi /qb TARGETDIR=$DepFolder\AzTemp /quiet" -Wait;
                      Copy-Item "$DepFolder\AzTemp\Microsoft SDKs\Azure\AzCopy\*" $DepFolder\AzCopy -Force;
                      Remove-Item $DepFolder\AZTemp -Recurse -Force;
                 }'
        DependsOn = 'AzCopy_Download'
    }
}
'@
```

## Run It

Starting from a clean module folder:

```
PS C:\> Get-ChildItem C:\MyModule -Recurse | Select-Object FullName

FullName
--------
C:\MyModule\MyModule.psd1
C:\MyModule\MyModule.psm1
C:\MyModule\Requirements.psd1
```

Import the module — PSDepend resolves all dependencies on first load:

```
PS C:\> Measure-Command { Import-Module C:\MyModule }

...
Seconds : 11
```

Initial load time depends on bandwidth. Subsequent imports are fast because PSDepend skips dependencies that are already present:

```
PS C:\> Measure-Command { Import-Module C:\MyModule -Force }

...
Seconds : 3
```

Confirm the dependencies were installed:

```
PS C:\> Get-ChildItem C:\MyModule\Dependencies -Recurse -Directory -Depth 1 | Select-Object FullName

FullName
--------
C:\MyModule\Dependencies\AzCopy
C:\MyModule\Dependencies\Posh-SSH
C:\MyModule\Dependencies\PSDepend
C:\MyModule\Dependencies\Posh-SSH\1.7.6
C:\MyModule\Dependencies\PSDepend\.build
```

Confirm the modules loaded from the local dependencies folder:

```
PS C:\> Test-PSDependExample

C:\MyModule\Dependencies\AzCopy
C:\MyModule\Dependencies\Posh-SSH
C:\MyModule\Dependencies\PSDepend
C:\MyModule\Dependencies\azcopy.msi
C:\MyModule\Dependencies\AzCopy\AzCopy.exe

Name      Path
----      ----
MyModule  C:\MyModule\MyModule.psm1
Posh-SSH  C:\MyModule\Dependencies\Posh-SSH\1.7.6\Posh-SSH.psd1
...
```

This pattern gives you a self-contained, repeatable module that pulls its own dependencies on first use — useful for build scripts, CI pipelines, or any module you want to work reliably across machines without a separate setup step.
