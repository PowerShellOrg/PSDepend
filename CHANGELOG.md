# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `PSResourceGet` dependency type for PowerShellGet v3 (#179).
- `InstallLocal` psake task for local pre-release installs (#180).
- Pester v5 unit tests for dependency scripts and reviewer checklist (#166).
- `CONTEXT.md` domain lexicon for PSDepend.
- Stale workflow for issues and PRs, with `workflow_dispatch` trigger.
- `Chocolatey` provider and accompanying Pester tests.
- SemVer / prerelease handling, including a PowerShell version constraint to avoid conflicts with the native `SemanticVersion` class in PS 6+.
- `AcceptLicense` and `AllowPrerelease` parameters on `PSGalleryModule` (passed only when specified).
- `AcceptLicense` for `PSRepositoryModule`.
- `Nuget` dependency type for pulling packages from arbitrary NuGet feeds, with custom DLL name support and `exe` support.
- Credential support across PSGallery scripts (`PSGalleryModule`, `PSGalleryNuget`) and `Invoke-PSDepend`; credentialed NuGet feed search; credential misconfiguration warning.
- `Funding.yml`.
- Core, macOS, and Linux support for `Nuget`.

### Changed
- Migrated the Pester test suite from v4 to v5 (#164).
- Modernized the build system to PowerShellBuild + GitHub Actions (#163); CI/CD actions updated (#168).
- Updated test setup to use the build script (#171).
- NuGet is now bootstrapped lazily, only when a `Nuget`/`PSGalleryNuget` dependency is used (#175).
- Renamed default branch references from `master` to `main`.
- Updated `README` and examples for `PowerShellOrg` ownership.
- Allowed overriding the dependency name in the `Github` dependency type (#121).
- Allowed GitHub version tags to match when using a `vX.Y.Z` tag instead of `X.Y.Z` (#123).
- Allowed passing `$null` to `Repository` so PSDepend relies on registered repositories instead of requiring an explicit one.
- Restored `SkipPublisherCheck` and `AllowClobber` handling that had been lost in a rebase.
- Added a `Conditional` repo option for `Find-Module`.

### Fixed
- Check all locally installed versions before querying the remote when an explicit version is requested (#176).
- Mock `Install-Dotnet` in the `DotnetSdk` install test (#178).
- `Chocolatey`: pass `--yes` to install and improve readability (#174).
- `Get-Dependency`: correct operator precedence bug when `DependencyType` is set via `PSDependOptions` (#131, #173).
- `Import-PSDependModule`: sanitize the version string passed to `Import-Module` (#140).
- `Git`: use the full `Dependency.Target` path when the target doesn't exist (#169).
- `Git`: remove dependency on the `git.exe` extension for cross-platform support.
- `Github`: speed up downloads by suppressing `Invoke-RestMethod` progress (#122).
- `PowerShellGet`: pass `-Scope` correctly when `Target=CurrentUser` (#167).
- Fix `'latest'` upgrade version-comparison logic in `PSGalleryModule` and `Package` scripts (#170).
- Add a check for empty strings (in addition to `$null`) (#102).
- Improve the error message when a `*.depend.psd1` file is missing (#126).
- Explicitly cast versions for comparison (#66).

### Docs
- Add a note about rerunning saved modules (#177).
- Credential help and credential misconfiguration warning.

## [0.3.0] - 2018-09-20

### Added
- `DotnetSdk` dependency type.

### Changed
- TLS 1.2 is now **added** to existing security protocols rather than replacing them (#85).
- Parameterized help for `Get-PSDependType`.
- GitHub download performance improvements (#84).

### Fixed
- `AllowClobber` placement in the `PSGalleryModule` splat (#83).
- GitHub import path bug.

## [0.2.1] - 2018-05-11

### Added
- PowerShell Core support (#79).
- `AllowClobber` parameter on `PSGalleryModule` (#53).
- Resolving of `PSDrives`.
- Error-handling parameters on dependency scripts.

### Changed
- Local build-environment improvements (#78).
- Tests now use `TestDrive` instead of `TargetPath`.
- `psake` build task allows `psd1` version overrides.
- Unmarked `Github` as experimental.
- Honor arbitrary target path logic for `Github` types.
- Removed `mkdir` from the module.

### Fixed
- Path delimiter on Linux.
- Conditional logic for removing parameters from splats.

## [0.2.0] - 2018-03-22

### Added
- Linux support (#72).
- Supported-platforms handling in `PSDependMap` (`windows`, `core`, `macos`, `linux`).
- Support for `.*requirements.psd1` filenames and hidden dependency files.
- `ImportName` to override the imported module name.
- TLS 1.2 added to the security protocol list.

### Changed
- Use capitalized `Noop` to avoid case-sensitivity issues on Linux.
- Improved verbosity, descriptions, and variable naming across scripts.
- Core-friendly `TargetPath` handling.

### Fixed
- Bug that missed hidden `*.depend.psd1` files.
- Alias resolution.

## [0.1.63] - 2018-01-17

### Added
- GitHub dependency type rewrite: versioned folders, version targets, multiple-version support, "latest" GitHub version lookup, scope keyword support, examples.
- `SkipPublisherCheck` for PSGallery modules (#46, #64).

### Changed
- `AddToPath` now applies on both install **and** subsequent imports (#60).
- Performance: removed redundant `Get-PSRepository` calls (#52); reduced calls to find the latest version of a module/package (#58).

### Fixed
- Ensure the correct version of a module is imported (#57).
- Doubled-folder bug, version bug, and import bug in the GitHub rewrite.
- Resolve `Target` correctly (#56).

## [0.1.56] - 2017-10-04

### Added
- `Npm` dependency type with unit tests.
- `PreScripts` and `PostScripts` with injected variables.
- Module extraction in the `Git` dependency script.
- Initial simple-syntax with namespaces (#41).

### Changed
- Full-path resolution for `AddToPath`, including when relative.

### Fixed
- Documentation typos.
- `PreScripts` and `PostScripts` feature bugs.

## [0.1.49] - 2017-03-19

### Added
- `Github` dependency type with default target handling.
- `Command` dependency type.
- `Package` dependency type with examples and tests.
- `FileSystem` dependency type.
- Hashtable input support for `Get-Dependency` and `Invoke-PSDepend`.
- `PSDependOptions` for global defaults (including global `DependencyType`, #15).
- `Invoke-DependencyScript` and tests.
- `$DependencyFolder`, `$PWD`, and `.` substitutions in `psd1` files.
- Sanitized environment-variable substitution in dependency definitions.
- Per-dependency `Target` override.
- `-Quiet` switch on `Invoke-PSDepend`.
- Extending-PSDepend documentation.

### Changed
- Adjusted `-Force` behavior on Module dependency types (#15).
- Hardcoded `Repository` removed from `PSGalleryModule.ps1`.
- Changed NuGet download path in the curl/bash install.

### Fixed
- Dependency parsing / `DependencyType` issue.
- Missing dependency type detection.
- Comment-based help for `Invoke-PSDepend`.
- Link to `Install-PSDepend`.
- `AddToPath` behavior and example scenarios.
- Module target doesn't exist + `-Force`.

## [0.0.30] - 2016-08-28

### Added
- `Test-Dependency`, `Import-Dependency`, and `Install-Dependency` actions.
- `Git` dependency type with branch/commit support.
- `PSGalleryNuget` dependency type.
- `PSGalleryModule` with `Force`, import-on-install option, and NuGet package-provider bootstrap.
- `FileDownload` dependency type.
- Support for `requirements.psd1` filename.
- AppVeyor CI hookup and initial test suite.
- `about_PSDepend` help and notes about PSDeploy.

### Fixed
- Bug in `Git` account/repo regex.
- Bug in `PSGalleryNuget`.
- Default Git dependency type discovery.
- `Invoke-PSDepend` `-Force` switch bug.

## [0.0.1] - 2016-07-29

### Added
- Initial scaffolding, adapted from PSDeploy.
