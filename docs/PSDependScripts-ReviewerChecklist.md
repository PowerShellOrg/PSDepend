# PSDependScripts — Reviewer Checklist

A guide for writing and reviewing dependency scripts in `PSDepend/PSDependScripts/`.
Each script implements a single `DependencyType` (e.g. `PSGalleryModule`, `Git`,
`Chocolatey`) and is dot-sourced by `Invoke-DependencyScript`.

## Established patterns (best practices)

### 1. Standard parameter contract

- First parameter is `[PSTypeName('PSDepend.Dependency')][PSObject[]]$Dependency`.
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

### 7. Local-first resolution for explicit versions

When a Dependency declares an explicit version (not `'latest'` or `''`):

1. Check **all** locally installed versions against the requested version before
   making any remote call.
2. Use typed comparison (`[System.Version]` → `[SemanticVersion]` → string
   equality) rather than string comparison — `"1.0"` and `"1.0.0.0"` are the
   same version.
3. Only fall through to the remote registry if no local match is found.
4. The `'latest'` path legitimately requires a remote call to confirm currency;
   the explicit-version path does not.

This keeps air-gapped and CI environments fast, avoids unnecessary network cost,
and is consistent with the principle that PSDepend should be idempotent.

### 8. Logging discipline

- `Write-Verbose` for normal progress on each decision branch.
- `Write-Error` (not `throw`) for recoverable failures.
- `Write-Warning` for skip-and-continue cases (see `Task.ps1`).

### 9. External tool and endpoint currency

Wrapper scripts break when the thing they wrap moves, not just when the
PowerShell is wrong. `choco list` silently changed meaning in Chocolatey 2.0
(local-only by default, `--local-only` removed, remote queries moved to
`choco search`) and the script kept passing review because every *mechanics*
check still passed — see issue #187.

- Know the CLI contract for every major version of the tool the script
  supports, and version-gate flags that changed (see `Get-ChocoVersion` in
  `Chocolatey.ps1`).
- Default endpoint URLs go stale: prefer the current canonical host
  (e.g. `community.chocolatey.org`, not the legacy `chocolatey.org` redirect)
  and note known-legacy defaults (the nuget.exe scripts still default to
  v2 OData feeds).
- If the underlying provider is deprecated upstream (PowerShellGet v2,
  PackageManagement), the script's help must say so and point at the
  supported alternative (see `PSResourceGet.ps1`).

### 10. Output-stream hygiene

A dependency script's return value *is* its output stream — `Test` returns
booleans through it. Any cmdlet that emits objects (`New-Item`, `Copy-Item
-PassThru`, `Install-Package`) must be assigned to `$null` or piped to
`Out-Null`, or it corrupts the Test result seen by the engine.

## Reviewer checklist

Use this as a PR review checklist when adding or modifying a script under
`PSDepend/PSDependScripts/`.

### Contract

- [ ] First param is `[PSTypeName('PSDepend.Dependency')][PSObject[]]$Dependency`.
- [ ] `PSDependAction` is `[ValidateSet(...)]` and lists only implemented actions.
- [ ] Type-specific params are top-level (not buried in
      `$Dependency.Parameters` lookups inside the body).

### Help

- [ ] `.SYNOPSIS` and `.DESCRIPTION` are present.
- [ ] "Relevant Dependency metadata" block enumerates **every** `$Dependency.*`
      field the script reads.
- [ ] Every field the help documents is **actually read by the code** — and
      every documented parameter exists in the param block. Drift in either
      direction ships a silent no-op or a binding error (`Task.ps1` documented
      `Target` while the code read only `Source`; `FileSystem.ps1` documented
      `Force`/`Mirror` with no matching parameters).
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
- [ ] No pipeline pollution: object-emitting cmdlets (`New-Item`,
      `Install-Package`, etc.) are assigned to `$null` so stray objects don't
      corrupt the `Test` boolean in the output stream.
- [ ] Verbose messages on each decision branch.
- [ ] Cross-platform paths use `Join-Path` (not string concat with `\`).

### External tool currency

- [ ] The script's CLI calls are valid on **every major version of the
      external tool it claims to support** — flags and subcommands that
      changed between majors are version-gated (Chocolatey 2.0 removed
      `--local-only` and made `choco list` local-only; see issue #187 and
      `Get-ChocoVersion` in `Chocolatey.ps1`).
- [ ] Default registry/feed URLs are the current canonical endpoints, not
      legacy redirects.
- [ ] Unauthenticated calls to rate-limited public APIs (e.g.
      `api.github.com`) honor `Credential` so CI runs don't hit limits.
- [ ] If the wrapped provider is deprecated upstream, the help says so and
      names the supported successor.

### Version comparison (for installers)

- [ ] When an explicit version is requested, **all locally installed versions
      are checked before any remote call is made** — the check must not be
      limited to the maximum installed version (see `PSGalleryModule.ps1`).
- [ ] Version comparison uses `[System.Version]::TryParse`, falling back to
      `[System.Management.Automation.SemanticVersion]::TryParse`, then string
      equality — never raw string equality alone (handles `"1.0"` vs `"1.0.0.0"`).
- [ ] `'latest'` vs explicit-version paths each produce a defensible
      early-return; only the `'latest'` path is allowed to hit a remote registry.

### Security / hygiene

- [ ] No plaintext credentials emitted in `Write-Verbose`.
- [ ] No secrets passed as external-process **command-line arguments** where
      avoidable — argv is visible to any process lister and to verbose
      command echoing (`Chocolatey.ps1` passes `--password='<plaintext>'`
      to choco; prefer the tool's config/env mechanism when one exists, and
      flag any new occurrence).
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
