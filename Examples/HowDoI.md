# How Do I

Common scenarios and recipes for working with PSDepend.

## Specify global defaults

Use the special `PSDependOptions` node to set defaults that apply to all dependencies in the file:

```powershell
@{
    PSDependOptions = @{
        Target = 'C:\MyProject'
        DependencyType = 'PSGalleryNuget'
    }

    'PSDeploy'      = 'latest'
    'BuildHelpers'  = 'latest'
    'Pester'        = 'latest'
    'InvokeBuild'   = 'latest'
}
```

All dependencies without an explicit override will be downloaded to `C:\MyProject` using `PSGalleryNuget`.

The following properties can be set in `PSDependOptions`:

- `Parameters`
- `Source`
- `Target`
- `AddToPath`
- `Tags`
- `DependsOn`
- `PreScripts`
- `PostScripts`

## Override a global default for specific dependencies

Individual dependencies can override any value set in `PSDependOptions`:

```powershell
@{
    PSDependOptions = @{
        Target = 'C:\MyProject'
        DependencyType = 'PSGalleryNuget'
    }

    'PSDeploy'     = 'latest'
    'BuildHelpers' = 'latest'
    'Pester' = @{
        Target = 'C:\sc'
    }
    'InvokeBuild' = 'latest'
}
```

All modules install to `C:\MyProject` except `Pester`, which installs to `C:\sc`.

## Set a single target for all dependencies

```powershell
@{
    PSDependOptions = @{
        Target = 'C:\MyTarget'
    }

    PSDeploy = 'latest'
    'PowerShellOrg/PSDepend' = 'master'
}
```

## Set a default target with per-dependency overrides

```powershell
@{
    PSDependOptions = @{
        Target = 'C:\MyTarget'
    }

    PSDeploy  = 'latest'
    PSSlack   = 'latest'
    PSJira = @{
        Target = 'C:\OtherTarget'
    }
    'PowerShellOrg/PSDepend' = 'master'
}
```
