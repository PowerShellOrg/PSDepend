# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.1] - 2026-06-12

### Added

- Reviewer checklist guidance for dependency scripts covering external
  tool/endpoint currency (version-gating CLI flags across tool majors),
  docs-vs-code drift, secrets on process command lines, and
  output-stream hygiene — the blind spots that let #187 ship (#189).

### Changed

- `GitHub` zip extraction now uses `Expand-Archive` instead of the COM
  `shell.application` API, which failed on Server Core and other
  non-interactive sessions; the module floor is PS 5.1, where
  `Expand-Archive` is always available (#189).

### Fixed

- `Chocolatey` handler is now compatible with Chocolatey 2.x: remote
  version queries use `choco search` (in 2.0, `choco list` stopped
  querying remote sources and rejects URL sources), and `--local-only`
  is passed only on 1.x, where it still exists, based on detection of
  the installed CLI version (#187, #189).
- `Chocolatey` default feed and bootstrap script URLs updated to
  `community.chocolatey.org`; fixed an undefined variable in the
  bootstrap error path and switched version checks to typed comparison
  so prerelease versions no longer throw or trigger reinstalls (#189).
- `PSGalleryNuget` "have latest" check compared version strings
  lexically, so `10.0.0` sorted below `9.0.0` and triggered needless
  reinstalls; it now uses typed SemVer/Version comparison (#189).
- `FileSystem` missing-source errors were silenced by an operator
  precedence bug, and the documented `Force` / `Mirror` parameters were
  absent from the param block, so passing them was a binding error.
  `Force` is now wired: it overwrites target files even where the
  target copy is newer (#189).
- `Task` only read `Source` while its help documented `Target`, so the
  documented usage silently ran zero tasks; both are now honored (#189).
- `Git` handler stops after reporting that git is not installed instead
  of attempting to invoke it anyway (#189).
- `Command` verbose output referenced the wrong loop variable when
  processing multiple dependencies (#189).
- Help tests now iterate parameters correctly during Pester discovery
  and use the right variable names in assertions.

## [0.4.0] - 2026-05-26

### Added

- `PSResourceGet` dependency type providing first-class support for
  PowerShellGet v3 (`Microsoft.PowerShell.PSResourceGet`) alongside the
  existing `PSGalleryModule` handler (#179).
- `InstallLocal` psake task that stages files and installs the module
  to `CurrentUser` scope from `Output\`, useful for validating
  pre-release bits locally without publishing (#180).
- `Chocolatey` dependency type with handler script and Pester
  coverage, enabling Chocolatey packages alongside PowerShell modules
  in `requirements.psd1`.
- `Nuget` dependency type for arbitrary NuGet feeds (not just the
  PowerShell Gallery), including custom DLL name support and the
  ability to extract `.exe` payloads.
- Credential support across `PSGalleryModule`, `PSGalleryNuget`, and
  `Invoke-PSDepend`, including credentialed NuGet feed search and a
  warning when credential configuration looks wrong.
- Core, macOS, and Linux platform tags on `Nuget` in
  `PSDependMap.psd1`, enabling cross-platform use.
- SemVer / prerelease handling for module versions, with a PowerShell
  version guard so PSDepend's `SemanticVersion` does not collide with
  the native `System.Management.Automation.SemanticVersion` class in
  PS 6+; falls back to `System.Version` when a version string is not
  SemVer-compatible.
- `AcceptLicense` parameter on `PSRepositoryModule` and matching
  `AcceptLicense` + `AllowPrerelease` plumbing on `PSGalleryModule`,
  splatted only when explicitly specified to preserve compatibility
  with older PowerShellGet versions.
- Stale workflow (`.github/workflows/stale.yml`) for issues and PRs,
  with a `workflow_dispatch` trigger for on-demand sweeps.
- `CONTEXT.md` documenting the PSDepend domain lexicon (Dependency,
  DependencyType, Target, Scope, `PSDependAction`, etc.) for both
  human and AI contributors.

### Changed

- Migrated the entire Pester test suite from v4 to v5 (#164),
  including new Pester v5 unit tests for individual dependency-type
  handler scripts and a reviewer checklist documenting the migration
  conventions (#166).
- Build system rewritten on top of `PowerShellBuild` with GitHub
  Actions replacing the prior AppVeyor pipeline (#163); CI workflow
  actions were updated to current major versions across the board
  (#168).
- Test bootstrap now runs through `build.ps1` (`Bootstrap` / `StageFiles`
  / `Test`) rather than ad-hoc setup, so tests always import from
  `Output\` and not the source tree (#171). See `CLAUDE.md` for the
  contract.
- `FunctionsToExport` in `PSDepend.psd1` is now an explicit list of
  the eight public commands instead of `*`, matching PowerShell module
  guidance and improving discoverability.
- NuGet command-line bootstrap is now lazy: it runs only when a
  `Nuget` or `PSGalleryNuget` dependency is actually used, instead of
  on every module import (#175).
- Default branch references updated from `master` to `main` across
  `README`, examples, the manifest's `LicenseUri` / `ProjectUri` /
  `ReleaseNotes` links, and build/CI scripts.
- README and example dependency files updated to reflect the
  `PowerShellOrg` ownership of the project.
- `Github` dependency type now allows overriding the imported name
  via the standard `Name` key, instead of always deriving it from the
  `owner/repo` slug (#121).
- `Github` version matching now accepts a `vX.Y.Z` tag when the
  dependency requests `X.Y.Z`, so dependencies written without the
  `v` prefix resolve against the common GitHub release-tag convention
  (#123).
- `PSGalleryModule` may now be invoked without an explicit
  `Repository`, in which case PSDepend defers to whatever repositories
  are currently registered via `Get-PSRepository` rather than forcing
  the PowerShell Gallery.

### Fixed

- `Get-Dependency` operator-precedence bug when `DependencyType` is
  set inside `PSDependOptions`: parenthesization was incorrect, so the
  global default failed to apply to dependencies without an explicit
  type (#131, #173).
- `Find-PSDependLocally` now consults *all* installed versions of a
  module before querying the remote when an explicit version is
  requested, rather than short-circuiting on the first non-matching
  local copy and re-downloading unnecessarily (#176).
- `Import-PSDependModule` now sanitizes the version string before
  passing it to `Import-Module`, preventing failures when prerelease
  segments or `vX.Y.Z` tags appear in the resolved version (#140).
- `Chocolatey` install path now passes `--yes` to `choco install`
  (previously the script contained the typo `--yess`), so installs
  no longer hang waiting on confirmation, and the surrounding code
  was tidied for readability (#174).
- `Git` handler now uses the full `Dependency.Target` path when the
  target directory doesn't yet exist, fixing a regression where
  relative targets would resolve against the wrong working directory
  (#169).
- `Git` handler no longer depends on the `.exe` extension when
  invoking `git`, so it works on macOS / Linux installations where the
  binary is just `git`.
- `Github` downloads suppress `Invoke-RestMethod`'s progress stream,
  yielding a measurable speed-up on large release-asset downloads
  (#122).
- `PowerShellGet` package handler now forwards `-Scope` correctly
  when `Target=CurrentUser`, instead of silently installing to the
  default scope (#167).
- Version comparison logic for `'latest'` upgrades in
  `PSGalleryModule` and `Package` scripts now compares
  `[System.Version]` values rather than strings, so `10.0.0` no longer
  sorts below `9.0.0` (#170).
- Empty-string guard added alongside existing `$null` checks in
  dependency-name handling, preventing silent skips when a malformed
  `requirements.psd1` produces a zero-length name (#102).
- `Test-Dependency` and friends now emit a clearer error message
  when `*.depend.psd1` is missing, instead of the previous opaque
  parse failure (#126).
- `DotnetSdk` install test now mocks `Install-Dotnet` so the test
  suite no longer attempts a real SDK install on CI runners (#178).

### Docs

- Added a note that `Save-Module` may need to be rerun if a
  dependency's `Target` directory was removed between invocations
  (#177).
- Credential help and a credential-misconfiguration warning added to
  the relevant handler scripts and `Invoke-PSDepend` help.

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
