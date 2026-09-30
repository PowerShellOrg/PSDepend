[![CI](https://github.com/PowerShellOrg/PSDepend/actions/workflows/ci.yml/badge.svg)](https://github.com/PowerShellOrg/PSDepend/actions/workflows/ci.yml)

# PSDepend

PSDepend is a PowerShell dependency handler. Define your dependencies in a simple `.psd1` file and let `Invoke-PSDepend` install them — similar to `pip install -r requirements.txt` or `bundle install`.

## Installing

```powershell
# PowerShell 7+ (recommended)
Install-PSResource PSDepend

# PowerShell 5.1
Install-Module PSDepend

# Manual
# Download and unblock the repository zip, then extract the PSDepend folder
# to a module path (e.g. $env:USERPROFILE\Documents\WindowsPowerShell\Modules\)
```

## Quick Start

```powershell
Import-Module PSDepend
Get-Command -Module PSDepend
Get-Help about_PSDepend
```

## Defining Dependencies

Store dependencies in a PowerShell data file named `*.depend.psd1` or `requirements.psd1`. `Invoke-PSDepend` will find these files automatically.

### Simple syntax

```powershell
@{
    psake        = 'latest'
    Pester       = 'latest'
    BuildHelpers = '0.0.20'
    PSDeploy     = '0.1.21'

    'PowerShellOrg/PSDepend' = 'main'
}
```

PSDepend infers `PSGalleryModule` for bare names and `GitHub` for `owner/repo` entries:

```
DependencyName          DependencyType  Version Tags
--------------          --------------  ------- ----
psake                   PSGalleryModule latest
BuildHelpers            PSGalleryModule 0.0.20
Pester                  PSGalleryModule latest
PowerShellOrg/PSDepend  GitHub          main
PSDeploy                PSGalleryModule 0.1.21
```

You can also specify the dependency type explicitly:

```powershell
@{
    'PSGalleryModule::InvokeBuild'       = 'latest'
    'GitHub::PowerShellOrg/PSDepend'     = 'main'
}
```

### Flexible syntax

For more control, use the hashtable syntax. You can mix and match styles within the same file:

```powershell
@{
    psdeploy = 'latest'

    buildhelpers_0_0_20 = @{
        Name = 'buildhelpers'
        DependencyType = 'PSGalleryModule'
        Parameters = @{
            Repository = 'PSGallery'
            SkipPublisherCheck = $true
        }
        Version = '0.0.20'
        Tags = 'prod', 'test'
        PreScripts = 'C:\RunThisFirst.ps1'
        DependsOn = 'some_task'
    }

    some_task = @{
        DependencyType = 'task'
        Target = 'C:\RunThisFirst.ps1'
        DependsOn = 'nuget'
    }

    nuget = @{
        DependencyType = 'FileDownload'
        Source = 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe'
        Target = 'C:\nuget.exe'
    }
}
```

To inspect the full dependency output:

```powershell
$Dependency = Get-Dependency \\Path\To\complex.depend.psd1
$Dependency[2] | Select-Object *
```

```
DependencyFile : \\Path\To\complex.depend.psd1
DependencyName : buildhelpers_0_0_20
DependencyType : PSGalleryModule
Name           : buildhelpers
Version        : 0.0.20
Parameters     : {Repository,SkipPublisherCheck}
Source         :
Target         :
AddToPath      :
Tags           : {prod, test}
DependsOn      : some_task
PreScripts     : C:\RunThisFirst.ps1
PostScripts    :
Raw            : {Version, Name, Tags, DependsOn...}
```

The following strings are expanded in `Target` and `Source` fields: `$PWD` (or `.`), `$ENV:USERPROFILE`, `$ENV:TEMP`, `$ENV:ProgramData`, `$ENV:APPDATA`. Use single quotes or escape the `$` to prevent PowerShell from expanding them before PSDepend can: `Target = '$PWD\dependencies'`.

### Repository Credentials

For private repositories that require authentication, set a `Credential` key in the dependency and pass a matching `PSCredential` object to `Invoke-PSDepend`:

```powershell
@{
    buildhelpers_0_0_20 = @{
        Name = 'buildhelpers'
        DependencyType = 'PSGalleryModule'
        Parameters = @{
            Repository = 'MyPrivateGallery'
        }
        Version = '0.0.20'
        Credential = 'my_gallery'
    }
}
```

```powershell
Invoke-PSDepend -Path C:\requirements.psd1 -Credentials @{ 'my_gallery' = $creds }
```

The credential key must match between the dependency definition and the hashtable passed to `-Credentials`.

## Locking Dependencies

Like npm's `package-lock.json`, PSDepend can pin every dependency — and the dependencies *they* pull in — to exact versions so that every machine installs the same thing:

```powershell
Update-PSDependLock -Path .\requirements.psd1   # writes requirements.lock.json
Invoke-PSDepend -Path .\requirements.psd1       # installs the locked versions
```

`Update-PSDependLock` asks each dependency type that supports the `Resolve` action (`PSGalleryModule`, `PSResourceGet`, `PSGalleryNuget`, `Nuget`, `Chocolatey`, `Npm`) for the highest version that satisfies the declared `Version` and walks that package's own dependencies. The gallery, NuGet, and Chocolatey types accept NuGet ranges; `Npm` accepts npm semver ranges such as `^1.2.0` or `>=1 <2` and rejects NuGet range syntax. `Npm` pins only the declared package because npm's own `package-lock.json` governs its subtree.

One version is locked per `DependencyType::Name`. Resolution is greedy: after selecting a parent version, PSDepend intersects child constraints but does not backtrack to an older parent version. Narrow the parent's range if an older version is required. Packages reached from roots with different installation contexts are installed once per root.

Once a lock exists next to a dependency file, `Invoke-PSDepend` and `Get-Dependency` use it automatically. Locked transitive packages install first. A changed dependency, version, resolution source, or DependencyScript parameter makes the lock out of date; removing every dependency does too. Pass `-IgnoreLock` to use the DependencyFile without the lock. With `Invoke-PSDepend -Test`, locked root and transitive versions are tested.

Commit the `.lock.json` alongside the DependencyFile and review lock changes like code. PSDepend validates its structure and exact versions before use, but version 1 does not contain package content hashes.

The JSON contains `lockfileVersion`, `dependencies`, and `packages`. Root entries record the requested version, `DependencyType::Name` package key, and a hash of resolution Source/Parameters. Package entries record an exact `version` and direct dependency ranges. Synthesized transitive Dependency names normally use `Name@Version`; a `#RootName` suffix disambiguates a package installed for another root context.

Dependency types without a `Resolve` action (`Git`, `GitHub`, `FileDownload`, ...) are recorded in the lock for drift detection but install exactly as declared.

## Getting Help

Each dependency type may handle standard properties differently and expose its own parameters. Use `Get-PSDependType` to see what is available:

```powershell
Get-PSDependType
```

```
DependencyType  Description                                                 DependencyScript
--------------  -----------                                                 ----------------
PSGalleryModule Install a PowerShell module from the PowerShell Gallery.    C:\...\PSDepend\PSDepen...
Task            Support dependencies by handling simple tasks.              C:\...\PSDepend\PSDepen...
Noop            Display parameters that a depends script would receive...   C:\...\PSDepend\PSDepen...
FileDownload    Download a file                                             C:\...\PSDepend\PSDepen...
```

Read the comment-based help for any dependency type:

```powershell
Get-PSDependType -DependencyType PSGalleryModule -ShowHelp
```

Additional help topics:

```powershell
Get-Help about_PSDepend
Get-Help about_PSDepend_Definitions
Get-Help Get-Dependency -Full
```

## Extending PSDepend

PSDepend is extensible. To add a new dependency type, create a script in the [PSDependScripts folder](https://github.com/PowerShellOrg/PSDepend/tree/main/PSDepend/PSDependScripts) and register it in [PSDependMap.psd1](https://github.com/PowerShellOrg/PSDepend/blob/main/PSDepend/PSDependMap.psd1).

Your script must:

- Include comment-based help describing how it uses `Dependency` metadata
- Accept a `PSDependAction` parameter with any actions it implements (`Install`, `Test`, `Import`, and optionally `Resolve`)
- For `Resolve`, query only and emit one `PSDepend.ResolvedDependency` with an exact `Version` and direct `Dependencies`; do not install

See [Git.ps1](https://github.com/PowerShellOrg/PSDepend/blob/main/PSDepend/PSDependScripts/Git.ps1) and [PSGalleryModule.ps1](https://github.com/PowerShellOrg/PSDepend/blob/main/PSDepend/PSDependScripts/PSGalleryModule.ps1) for reference implementations.

## Examples

- [Creating a virtual environment](/Examples/VirtualEnvironment.md)
- [Handling module dependencies](/Examples/ModuleDependencies.md)
- [How Do I...](/Examples/HowDoI.md)

## Contributing

Contributions are welcome. Please read the [PowerShellOrg contributing guide](https://github.com/PowerShellOrg/.github/blob/main/.github/CONTRIBUTING.md) before opening a pull request.

## Acknowledgements

PSDepend was originally created by [Warren Frame (RamblingCookieMonster)](https://github.com/RamblingCookieMonster) and is now maintained by the [PowerShellOrg](https://github.com/PowerShellOrg) organization.

The concept was inspired by Michael Willis's [PSRequire](https://github.com/Xainey/PSRequire).
