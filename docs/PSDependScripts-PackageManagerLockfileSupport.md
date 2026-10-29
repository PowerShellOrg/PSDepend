# PSDependScripts package-manager lockfile support

## Scope and terms

This is an audit of the handlers in `PSDepend/PSDependScripts`. A **native
lockfile** here is a manager-maintained record of resolved dependencies that a
frozen/locked operation consumes without re-resolving it. A PSDepend
`Dependency.Version` value is an input pin (or range), not such a file.

The handler links in the table are the primary source for the command actually
invoked. The numbered links are first-party tool documentation or source.

| Handler | Manager/tool actually invoked | Native lockfile / locked mode | Relevant behavior and constraints | Evidence |
| --- | --- | --- | --- | --- |
| [Chocolatey](../PSDepend/PSDependScripts/Chocolatey.ps1) | `choco.exe list`, `search`, and `upgrade`; installation passes `--version` only for an explicit PSDepend version. | **No generated resolved lockfile or lock mode documented.** Chocolatey accepts a user-authored `packages.config` manifest, but this handler does not invoke it. | A `packages.config` entry may directly specify `version`; Chocolatey also has installed-package `pin`. Neither records/enforces a resolved transitive graph. This handler's `Version` is therefore a direct pin, not a lock. | [Chocolatey install / `packages.config`][1]; [Chocolatey pin][2] |
| [Npm](../PSDepend/PSDependScripts/Npm.ps1) | Internal `Install-NodeModule` calls `npm install --silent [--global] <name>@<version>`. | **Yes: `package-lock.json`; frozen mode: `npm ci`.** The handler does **not** invoke `npm ci` or pass a lock-specific option. | npm auto-generates/updates `package-lock.json` for tree or manifest changes. `npm ci` requires `package-lock.json` or `npm-shrinkwrap.json`, fails when it conflicts with `package.json`, and never writes either. Thus this handler can update/use a local npm lock during `npm install`, but does not offer frozen lockfile enforcement; global installs are outside a project lock. Reuse tree-shaping flags (for example, `--legacy-peer-deps`) with `npm ci`. | [npm lockfile][3]; [npm CI][4]; [helper source](../PSDepend/Private/Install-NodeModule.ps1) |
| [Nuget](../PSDepend/PSDependScripts/Nuget.ps1) | `nuget install <name> -Source <source> -ExcludeVersion -NonInteractive -OutputDirectory <target> [-Version <version>]`. | **NuGet supports `packages.lock.json` only for PackageReference project restore; this handler does not use it.** | Native locked restore is `nuget restore -UseLockFile -LockedMode` (or equivalent `dotnet`/MSBuild restore). `nuget install` is a direct package/config download and has no locked-mode option; this handler does not call `restore`, provide a project, or read/write a lockfile. Its `-Version` is a direct pin. | [NuGet PackageReference locking][5]; [NuGet restore][6]; [NuGet install][7] |
| [PSGalleryModule](../PSDepend/PSDependScripts/PSGalleryModule.ps1) | PowerShellGet `Find-Module`, then `Install-Module` or `Save-Module`; exact versions become `-RequiredVersion`. | **No native generated resolved lockfile or locked mode in PowerShellGet v2.** | The handler resolves a PSDepend NuGet-style range itself to the highest matching version, then invokes `-RequiredVersion`; this is a direct selected-version pin. `Install-Module` exposes exact/minimum/maximum version parameters, not a lockfile or locked operation. | [PowerShellGet `Install-Module`][8] |
| [PSGalleryNuget](../PSDepend/PSDependScripts/PSGalleryNuget.ps1) | `nuget install` against the PowerShell Gallery NuGet v2 feed, with `-ExcludeVersion`, `-NonInteractive`, `-OutputDirectory`, and optional exact `-Version`. | **No.** NuGet PackageReference locking is not a lockfile facility for PowerShell Gallery module installation. | The handler resolves a PSDepend range to an exact version before calling direct `nuget install`; it never calls NuGet project `restore` or its lock switches. Feed protocol alone does not change the operation into PackageReference restore. | [NuGet PackageReference locking][5]; [NuGet install][7] |
| [PSResourceGet](../PSDepend/PSDependScripts/PSResourceGet.ps1) | `Find-PSResource`, then `Install-PSResource` or `Save-PSResource`; passes `-Version` for an explicit version/range. | **No native generated resolved lockfile or locked mode documented.** | `Install-PSResource` supports declarative `-RequiredResourceFile` (`.json`/`.psd1`) and version ranges, but this is a requirements input, not a manager-generated resolved lock. The handler does not expose `-RequiredResourceFile`; it resolves from its direct `Name`/`Version` input. The cmdlet also does not install dependent resources from NuGet v3 repositories. | [PSResourceGet `Install-PSResource`][9]; [cmdlet source][10] |
| [Package](../PSDepend/PSDependScripts/Package.ps1) | PackageManagement `Get-Package`, `Find-Package`, and `Install-Package`; provider selected by source or `ProviderName`. | **No uniform PackageManagement lockfile/locked mode.** | The handler passes direct `-RequiredVersion` when given and splats `Dependency.Parameters` into `Install-Package`. Provider-specific behavior must not be represented as PackageManagement-wide support; the documented generic and NuGet/PowerShellGet parameter sets expose version/destination/provider controls, not a common lock operation. | [PackageManagement `Install-Package`][11] |
| [Command](../PSDepend/PSDependScripts/Command.ps1) | Dot-sources a `ScriptBlock` created from `Dependency.Source`. | **N/A — not a package manager.** | Executes arbitrary PowerShell; no dependency resolver or lockfile interface. | [handler source](../PSDepend/PSDependScripts/Command.ps1) |
| [DotnetSdk](../PSDepend/PSDependScripts/DotnetSdk.ps1) | Internal `Install-Dotnet -Channel <channel> -Version <version> -InstallDir <path>`. | **N/A — SDK installer, not a package manager.** | The requested version/channel is input to the installer; this handler does not consume or create a lockfile. | [handler source](../PSDepend/PSDependScripts/DotnetSdk.ps1) |
| [FileDownload](../PSDepend/PSDependScripts/FileDownload.ps1) | Internal `Get-WebFile -URL <url> -Path <path>`. | **N/A — file downloader, not a package manager.** | Installs a URL-selected artifact; no lockfile or integrity-record mechanism is invoked. | [handler source](../PSDepend/PSDependScripts/FileDownload.ps1) |
| [FileSystem](../PSDepend/PSDependScripts/FileSystem.ps1) | `ROBOCOPY.exe` for folders; `Copy-Item` for files. | **N/A — filesystem copier, not a package manager.** | File copies compare SHA-256 source/target content; that runtime comparison is not a lockfile. Folder copies use `/E`, `/XO`, and optionally `/PURGE`. | [handler source](../PSDepend/PSDependScripts/FileSystem.ps1) |
| [Git](../PSDepend/PSDependScripts/Git.ps1) | `git clone`, then `git checkout <Version>`. | **N/A — source-control client, not a package manager.** | A commit hash supplied as `Version` can pin a checkout; a branch/tag name can move. Neither is a manager lockfile and the handler has no lockfile operation. | [handler source](../PSDepend/PSDependScripts/Git.ps1) |
| [GitHub](../PSDepend/PSDependScripts/GitHub.ps1) | GitHub tags/zipball REST endpoints, `Invoke-RestMethod`, `Expand-Archive`, `Copy-Item`. | **N/A — archive downloader, not a package manager.** | `Version` chooses a numeric tag or branch archive. The handler does not consume a lockfile or record artifact integrity. | [handler source](../PSDepend/PSDependScripts/GitHub.ps1) |
| [Noop](../PSDepend/PSDependScripts/Noop.ps1) | Emits received variables and environment data. | **N/A — diagnostic handler, not a package manager.** | It performs no dependency installation. | [handler source](../PSDepend/PSDependScripts/Noop.ps1) |
| [Task](../PSDepend/PSDependScripts/Task.ps1) | Dot-sources existing task scripts with supplied parameters. | **N/A — task runner, not a package manager.** | It executes files selected by `Source` or `Target`; there is no resolver or lockfile interface. | [handler source](../PSDepend/PSDependScripts/Task.ps1) |
| [WindowsRSAT](../PSDepend/PSDependScripts/WindowsRSAT.ps1) | `Install-WindowsFeature` on Server or `Add-WindowsCapability -Online` on Workstation. | **N/A — Windows component servicing, not a package manager.** | It maps an RSAT module to a Windows feature/capability and installs the system component; no lockfile is used. | [handler source](../PSDepend/PSDependScripts/WindowsRSAT.ps1) |

## Consequences for PSDepend

* Only the **Npm** handler calls a tool with a general-purpose native lockfile,
  but it uses mutable `npm install`, not frozen `npm ci`.
* **Nuget** has native project lock support, but neither `Nuget` nor
  `PSGalleryNuget` executes the required PackageReference `restore` path.
* Chocolatey's `packages.config`, PowerShellGet's `-RequiredVersion`,
  PSResourceGet's `-RequiredResourceFile`, and every handler's PSDepend
  `Version` value are declarative requirements or direct pins. They must not be
  described as native resolved lockfiles or locked mode.

## First-party sources

[1]: https://docs.chocolatey.org/en-us/choco/commands/install/
[2]: https://docs.chocolatey.org/en-us/choco/commands/pin/
[3]: https://docs.npmjs.com/cli/v11/configuring-npm/package-lock-json/
[4]: https://docs.npmjs.com/cli/v11/commands/npm-ci/
[5]: https://learn.microsoft.com/en-us/nuget/consume-packages/package-references-in-project-files#locking-dependencies
[6]: https://learn.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-restore
[7]: https://learn.microsoft.com/en-us/nuget/reference/cli-reference/cli-ref-install
[8]: https://learn.microsoft.com/en-us/powershell/module/powershellget/install-module?view=powershellget-2.x
[9]: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.psresourceget/install-psresource?view=powershellget-3.x
[10]: https://raw.githubusercontent.com/PowerShell/PSResourceGet/master/src/code/InstallPSResource.cs
[11]: https://learn.microsoft.com/en-us/powershell/module/packagemanagement/install-package?view=powershellget-2.x
