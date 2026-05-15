# PSDependScripts — Reviewer Checklist

A guide for writing and reviewing dependency scripts in `PSDepend/PSDependScripts/`.
Each script implements a single `DependencyType` (e.g. `PSGalleryModule`, `Git`,
`Chocolatey`) and is dot-sourced by `Invoke-DependencyScript`.

## Established patterns (best practices)

### 1. Standard parameter contract

- First parameter is `[PSTypeName('PSDepend.Dependency')][psobject[]]$Dependency`.
- `$PSDependAction` is `[ValidateSet(...)][string[]]` with **only** the actions
  the script actually implements (`Test`, `Install`, `Import`) and defaults to
  `@('Install')`.
- Type-specific options (`Repository`, `Source`, `Force`, `Global`,
  `ProviderName`, etc.) are top-level parameters — populated via
  `Parameters = @{ ... }` splat from the dependency hashtable.

### 2. Comment-based help is mandatory and follows a shape

- `.SYNOPSIS` / `.DESCRIPTION`.
- A **"Relevant Dependency metadata"** block describing how each
  `$Dependency.*` field (`Name`, `Version`, `Target`, `Source`, `Credential`,
  `AddToPath`, `Parameters.*`) is interpreted *by this dependency type*.
- A `.PARAMETER PSDependAction` block listing supported actions.
- At least one `.EXAMPLE` showing a real `@{ }` dependency hashtable. Most
  scripts include both a simple and an advanced example.

### 3. Field extraction at the top

Resolve the inputs once into locals before the main body runs:

- `$Name = $Dependency.Name`; fall back to `$Dependency.DependencyName`.
- `$Version = $Dependency.Version`; default to `'latest'`.
- `$Target` / `$Source` / `$Credential` with sensible defaults.

### 4. `PSDependAction` semantics

- `Test` alone returns `$true` / `$false`.
- `Test` combined with `Install` returns `$true` early when satisfied and falls
  through to install otherwise.
- `Install` does the work; `Import` (where supported) calls
  `Import-PSDependModule` against the resolved path.
- The canonical "nothing found, test-only" guard appears verbatim across scripts:

  ```powershell
  if ($PSDependAction -contains 'Test' -and $PSDependAction.Count -eq 1) {
      return $false
  }
  ```

### 5. External tool prerequisites

- Probe with `Get-Command <tool> -ErrorAction SilentlyContinue` and use
  `Write-Error` (not `throw`) when missing, so the dependency engine can
  continue with the rest of the run.
- Invoke external tools via `Invoke-ExternalCommand` (see `Git.ps1`,
  `Chocolatey.ps1`) rather than `& tool`, so output capture is consistent.

### 6. Path / scope semantics

- `Target` doubles as Scope: `AllUsers` / `CurrentUser` are install scopes;
  any other value is a filesystem path (Save vs Install branch).
- `AddToPath` consistently prepends to `$env:PATH` and/or `$env:PSModulePath`
  via `Add-ToItemCollection`.

### 7. Logging discipline

- `Write-Verbose` for normal progress on each decision branch.
- `Write-Error` (not `throw`) for recoverable failures.
- `Write-Warning` for skip-and-continue cases (see `Task.ps1`).

## Reviewer checklist

Use this as a PR review checklist when adding or modifying a script under
`PSDepend/PSDependScripts/`.

### Contract

- [ ] First param is `[PSTypeName('PSDepend.Dependency')][psobject[]]$Dependency`.
- [ ] `PSDependAction` is `[ValidateSet(...)]` and lists only implemented actions.
- [ ] Type-specific params are top-level (not buried in
      `$Dependency.Parameters` lookups inside the body).

### Help

- [ ] `.SYNOPSIS` and `.DESCRIPTION` are present.
- [ ] "Relevant Dependency metadata" block enumerates **every** `$Dependency.*`
      field the script reads.
- [ ] Every parameter has a `.PARAMETER` entry.
- [ ] At least one `.EXAMPLE` with a runnable `@{ }` hashtable.

### Dependency-field handling

- [ ] `Name` falls back to `DependencyName`.
- [ ] `Version` defaults to `'latest'` (or documents why not).
- [ ] `Target` default + scope-vs-path interpretation is documented.
- [ ] `Credential` is honored when the underlying provider supports it.
- [ ] `AddToPath` is honored where the install location is filesystem-based.

### Action semantics

- [ ] `Test` alone returns a single boolean.
- [ ] `Test` + `Install` short-circuits cleanly when satisfied (no install,
      but `Import-PSDependModule` still runs if applicable).
- [ ] Test-only "nothing found" returns `$false` via the canonical guard.
- [ ] `Import` (if supported) goes through `Import-PSDependModule`.

### Robustness

- [ ] External tool dependencies probed via
      `Get-Command -ErrorAction SilentlyContinue`.
- [ ] External invocations go through `Invoke-ExternalCommand`.
- [ ] Failures use `Write-Error` (not `throw`) unless terminating is intended
      (e.g. `FailOnError`).
- [ ] No `Out-Null` / `2>$null` swallowing of error streams.
- [ ] Verbose messages on each decision branch.
- [ ] Cross-platform paths use `Join-Path` (not string concat with `\`).

### Version comparison (for installers)

- [ ] Both `[SemanticVersion]::TryParse` and `[Version]::TryParse` are
      attempted before comparing (see `PSGalleryModule.ps1` lines 262–273).
- [ ] `'latest'` vs explicit-version paths each produce a defensible
      early-return.

### Security / hygiene

- [ ] No plaintext credentials emitted in `Write-Verbose`.
- [ ] No `Invoke-Expression` on dependency data. `Command.ps1` uses
      `[ScriptBlock]::Create` — that's the documented trust boundary;
      any new script doing this needs an explicit opt-in
      (e.g. `FailOnError`-style).
- [ ] TLS 1.2 forced before `Invoke-WebRequest` against public registries
      (see `Chocolatey.ps1:182`).

### Known smells to call out

- Helper functions defined inside dependency scripts (e.g. `Parse-URLForFile`
  in `FileDownload.ps1`, `Get-ChocoInstalledPackage` in `Chocolatey.ps1`)
  should arguably live in `PSDepend/Private/`. Flag if a new script adds
  local helpers — both for reuse and because **inline helpers cannot be
  mocked by Pester**.
- Direct `Invoke-Expression`-style dot-sourcing of user-supplied strings
  (see `Command.ps1`) requires explicit acknowledgement.
