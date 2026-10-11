# Prerelease Version Detection — Research Findings

Investigation backing the prerelease-version warning added to
`PSDepend/PSDependScripts/PSGalleryModule.ps1`:

```powershell
$isPrereleaseVersion = $versionRange.Exact -match '^\d+(\.\d+){1,3}-[0-9A-Za-z][0-9A-Za-z\.-]*$'
$allowsPrerelease = $PSBoundParameters.ContainsKey('AllowPrerelease') -and $AllowPrerelease
if ($isPrereleaseVersion -and -not $allowsPrerelease) {
    Write-Warning "..."
}
```

This document answers three research questions ahead of extracting the regex into a
`PSDepend/Private/` helper. **File placement note:** named
`PSDependScripts-PrereleaseVersionDetection.md` to match the existing flat,
topic-focused naming convention seen in `docs/PSDependScripts-ReviewerChecklist.md`
and `docs/PSDependScripts-PackageManagerLockfileSupport.md` (prefix identifies the
subsystem, suffix identifies the topic; no subfolder).

---

## Q1 — Why `$PSBoundParameters.ContainsKey('AllowPrerelease')` instead of `if ($AllowPrerelease)`?

### 1. Does PowerShellGet 1.0.0.1 (Windows PowerShell 5.1 inbox) support `-AllowPrerelease`?

No for the inbox version, yes once PowerShellGet is updated. `-AllowPrerelease` was added
to `Find-Module`/`Install-Module`/`Update-Module`/`Save-Module` in **PowerShellGet 1.6.0**,
as part of the "Prerelease Version Support" feature:

> "New features … \* Prerelease Version Support (#185) - Implemented prerelease versions
> functionality in PowerShellGet cmdlets. Enables publishing, discovering, and installing
> the prerelease versions of modules and scripts from the PowerShell Gallery."
— PowerShellGet release notes (`PrivateData.PSData.ReleaseNotes` in the module manifest),
section "1.6.0", https://www.powershellgallery.com/packages/PowerShellGet/2.2.5/Content/PowerShellGet.psd1

The inbox PowerShellGet shipped with Windows PowerShell 5.1 (WMF 5.1, released 2017) is
**1.0.0.1**, which predates 1.6.0 and therefore has **no `-AllowPrerelease` parameter at
all** on `Install-Module`/`Find-Module`. This is corroborated by the conceptual doc for
the feature, which frames `-AllowPrerelease` as something introduced "Starting with
version 1.6.0":

> "Starting with version 1.6.0, PowerShellGet and the PowerShell Gallery provide support
> for tagging versions greater than 1.0.0 as a prerelease. … Dealing with prerelease
> packages using PowerShellGet Find-Module, Install-Module, Update-Module, and
> Save-Module commands requires adding the `-AllowPrerelease` flag."
— https://learn.microsoft.com/en-us/powershell/gallery/concepts/module-prerelease-support

So any machine still on inbox PowerShellGet 1.0.0.1 (a real, supported scenario — many
CI/air-gapped Windows PowerShell 5.1 hosts never update PowerShellGet) will have an
`Install-Module` that **does not have** an `-AllowPrerelease` parameter.

### 2. Does explicit `-AllowPrerelease:$false` behave differently from omission?

Evidence found does **not** show a documented behavioral difference for `Install-Module`
itself between `-AllowPrerelease:$false` and omitting the parameter — the conceptual doc
and `Install-Module`/`Uninstall-Module` reference pages describe `-AllowPrerelease` as a
simple opt-in flag; there is no documented "tri-state" semantics (e.g. "unset" vs.
"explicitly false") for `Install-Module` or `Find-Module`. The one place a genuine
tri-state distinction is documented is `Uninstall-Module`, which treats "no
`-RequiredVersion`" as "remove latest" regardless of `-AllowPrerelease`, but that's
orthogonal to `$params.Add('AllowPrerelease', ...)` for `Install-Module`.
(https://learn.microsoft.com/en-us/powershell/gallery/concepts/module-prerelease-support,
"Uninstall-Module" section.)

### 3. Verdict

The `ContainsKey` guard is **still doing useful, non-redundant work today**, but for a
different reason than parameter-set compatibility alone — **it predates and is partially
subsumed by, but not fully redundant with, the generic filter**:

- The **generic filter** (`$availableParameters = (Get-Command "Install-Module").Parameters`,
  added in commit `06f6be1`, 2018-05-03) runs *after* `$Params` is built and strips any key
  whose name `Install-Module` doesn't recognize — this alone is sufficient to stop PSDepend
  from ever passing a literal `-AllowPrerelease` switch to an inbox 1.0.0.1 `Install-Module`
  (which has no such parameter), confirmed by reading the current script
  (`PSDepend/PSDependScripts/PSGalleryModule.ps1:311-318`).
- However, commit `072d776` (2020-07-04, "Only pass AcceptLicense and AllowPrerelease
  params if specified in PSGalleryModule") changed **both** `AllowPrerelease` **and**
  `AcceptLicense` from unconditional hashtable members (`AllowPrerelease = $AllowPrerelease`)
  to conditional ones. Before that commit, `$params` *always* contained
  `AllowPrerelease = $false` (the then-default) whenever `Install-Module` *did* support the
  parameter (e.g. any post-1.6.0 PowerShellGet). On such hosts, the generic filter does
  **not** remove the key (the parameter exists), so PSDepend was *always* passing
  `-AllowPrerelease:$false` explicitly to every `Install-Module` call, forcing
  `AcceptLicense` to `$true` by default too (silently auto-accepting license terms the
  user never opted into). The `ContainsKey` guard fixes that: it ensures PSDepend only
  passes these two parameters when the user actually set them in `Parameters = @{ }`,
  letting `Install-Module`'s own default behavior apply otherwise. This is stated
  verbatim in the commit's intent (commit message + diff removing the hardcoded
  `AcceptLicense = $True` default), https://github.com/<this-repo-remote>/commit/072d77622902f25397e71efc563051b42402f62
  (local: `git show 072d776`).
- So: **for the narrow question of "does `Install-Module` accept the parameter at all,"
  the generic filter alone is sufficient and the `ContainsKey` guard is redundant.** But
  the guard's *actual*, still-relevant purpose is different: it prevents PSDepend from
  silently overriding `Install-Module`'s own defaults for `AllowPrerelease` and
  `AcceptLicense` (most importantly, forcing license acceptance) on any host where the
  parameters exist. That purpose is **not** covered by the generic filter and remains
  necessary.

**Confidence: high** for the historical motivation (directly confirmed by the commit
diff and message) and for "generic filter alone would handle the
parameter-doesn't-exist case"; **high** for "the guard still matters" because the
`AcceptLicense` auto-$true regression is a real, observable behavior change that the
generic filter cannot prevent (it only filters by key name, not value).

---

## Q2 — Is `[System.Management.Automation.SemanticVersion]` safe to depend on for PS 5.1?

### 1. Which PowerShell version introduced it, and is it present/consistent in Windows PowerShell 5.1 inbox?

**`SemanticVersion` is NOT available by default in Windows PowerShell 5.1.** The type was
introduced as part of PowerShell Core's engine (`System.Management.Automation.dll`
shipped with PowerShell 6+), not the Windows PowerShell 5.1 inbox assembly. Confirmed by
PowerShellGet-adjacent history and, directly, by Microsoft's own PSScriptAnalyzer
`UseCompatibleTypes` rule documentation, which uses exactly this type as its worked
example of a type *missing* on 5.1:

> "`System.Management.Automation.SemanticVersion` isn't available by default in Windows
> PowerShell 5.1, so the rule flags this type usage for that target profile."
>
> ```powershell
> $version = [System.Management.Automation.SemanticVersion]'1.2.3'
> ```
> — flagged noncompliant against target profile
> `win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework` (Windows 10 Pro,
> PowerShell 5.1)
— https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/usecompatibletypes

This profile is generated by reflecting over the real, installed `System.Management.Automation.dll`
for that platform, so it is a direct, primary statement about the type's absence in the
inbox 5.1 assembly (not merely "untested" — PSScriptAnalyzer's compatibility checker
builds per-platform JSON manifests of every type actually present).

This also matches the iterative way the type was built out in the PowerShell/PowerShell
engine itself, long after Windows PowerShell 5.1 (WMF 5.1, 2017) shipped:

- PS 6.0-era: "Relax the PowerShell `SemanticVersion` constructors to not require
  'minor' and 'patch' portions…" (#3696); "Enable comparison between a `SemanticVersion`
  instance and a `Version` instance…" (#3793) — https://github.com/PowerShell/PowerShell/blob/master/CHANGELOG/6.0.md
- PS 6.1: `semver` added as a **type accelerator** for
  `System.Management.Automation.SemanticVersion` (#4142) —
  https://github.com/PowerShell/PowerShell/blob/master/CHANGELOG/6.0.md (6.1.0 section)
- PS 6.2: "Make `SemanticVersion` compatible with `SemVer 2.0`" (#5037) — same file,
  6.2.0 section.

**Practical consequence for PSDepend:** `PSDepend/Private/Test-PSDependExactVersion.ps1`
and `Compare-Version.ps1` call `[System.Management.Automation.SemanticVersion]::TryParse()`
unconditionally, with no `try`/`catch` around type resolution. On genuine Windows
PowerShell 5.1 (not PowerShell 7+ running on Windows), referencing this type throws a
`RuntimeException` ("Unable to find type…") rather than returning `$false` — this is a
real compatibility risk for the module's stated 5.1 support, independent of the
prerelease-detection feature. (This is a finding to flag for whoever owns those Private
helpers; it is out of scope for the regex extraction task itself, and no PowerShell
source file was modified as part of this investigation per the assignment.)

### 2. `SemanticVersion`'s parsing grammar (from source)

Source: `src/System.Management.Automation/engine/PSVersionInfo.cs` in the
PowerShell/PowerShell repo (the `SemanticVersion` struct lives in this file, not a
separate `SemanticVersion.cs`), lines 337-340:

```csharp
private const string VersionSansRegEx = @"^(?<major>\d+)(\.(?<minor>\d+))?(\.(?<patch>\d+))?$";
private const string LabelRegEx = @"^(?<preLabel>(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*)?(?:\+(?<buildLabel>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$";
private const string LabelUnitRegEx = @"^((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*)$";
private const string BuildUnitRegEx = @"^([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*)$";
```
— https://github.com/PowerShell/PowerShell/blob/master/src/System.Management.Automation/engine/PSVersionInfo.cs#L337-L340

Documented grammar derived from the regexes above:

- **Numeric component count:** `VersionSansRegEx` requires **1 to 3** numeric
  dot-separated components (`major` required; `minor`, `patch` optional). **4-part
  versions (`1.2.3.4`) are rejected outright** — `SemanticVersion` has no 4th
  "revision" component, unlike `System.Version`.
- **Prerelease label (`LabelRegEx`/`LabelUnitRegEx`):** one or more
  dot-separated identifiers (`(?:\.(?:...))*` — dots **are** allowed, i.e. SemVer 2.0
  style `1.0.0-beta.1` is accepted), where each identifier is either all-numeric with no
  leading zero (`0` or `[1-9]\d*`) or alphanumeric/hyphen (`\d*[a-zA-Z-][0-9a-zA-Z-]*`,
  i.e. must contain at least one non-digit).
- **Build metadata (`+...`):** supported via the same `LabelRegEx`
  (`(?:\+(?<buildLabel>[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?`) — one or more
  dot-separated alphanumeric/hyphen identifiers after a literal `+`.
  **Caveat:** a long-standing engine bug (fixed later, see below) rejected build
  metadata when no prerelease label was present, e.g. `1.0.0+asdf` originally threw
  `FormatException`, while `1.0.0-beta+asdf` worked — confirmed via
  https://github.com/PowerShell/PowerShell/issues/14605 (opened 2021-01-13 against
  PS 7.1.0, closed as fixed; a later `pwsh` 7.3.0 screenshot in the same thread shows it
  parsing correctly). Consumers targeting older PS 7.0/7.1 should not assume
  `1.0.0+build` parses.
- **What it rejects:** anything not matching `VersionSansRegEx` for the numeric part
  (so no 4-part versions, no non-digit characters in major/minor/patch, no leading `v`),
  and prerelease/build labels containing characters outside `[0-9A-Za-z-]` per identifier
  (dots are the only other allowed separator, and only *between* identifiers).

### Honoring PSDepend's existing repo convention

`docs/PSDependScripts-ReviewerChecklist.md`'s "Version comparison (for installers)"
section already documents the `[System.Version]` → `[SemanticVersion]` → string-equality
pattern used by `Test-PSDependExactVersion.ps1` / `Compare-Version.ps1`; this document
does not restate that guidance, only supplements it with the PS-5.1-availability caveat
above, which that checklist does not currently cover.

---

## Q3 — Validated test matrix of version strings

| # | Version string | (a) Plausible exact `Version` PSDepend could receive? | (b) `SemanticVersion.TryParse` accepts? | (c) Carries a prerelease label a human would expect a warning for? |
|---|---|---|---|---|
| 1 | `2.5.0-alpha` | **Yes.** Canonical real `Publish-Module -Prerelease alpha` shape: 3-part `ModuleVersion` + hyphen + alphanumeric prerelease tag. Matches the documented module-prerelease requirement ("Prerelease string may only be specified when the ModuleVersion is 3 segments… hyphen is the delimiter… [0-9A-Za-z-]"), https://learn.microsoft.com/en-us/powershell/gallery/concepts/module-prerelease-support#identifying-a-module-version-as-a-prerelease. | Yes — 3 numeric components + single alphanumeric prerelease identifier matches `VersionSansRegEx`/`LabelUnitRegEx`. | Yes. |
| 2 | `0.7.0-beta1` | **Yes.** Same shape, digit appended directly to the label (common convention: `-alpha1`, `-BETA`, `-update20171020` per the same doc's examples). This is the string used in PSGalleryModule.ps1's own comment-based help example. | Yes. | Yes. |
| 3 | `1.0.0-beta.1` | **SemVer-2.0-valid, but PSGallery-module-invalid.** The module-prerelease doc explicitly forbids dots in the module Prerelease field: "Prerelease string **must not** contain either period or + [.+], which are allowed in SemVer 2.0. Only SemVer v1.0.0 prerelease strings are supported." A real `Publish-Module -Prerelease` call with a dotted tag is rejected at publish time, so this string should not appear as a module's exact version from the Gallery. It *can* still appear in `Dependency.Version` if a user hand-writes a PSDepend file expecting NuGet/SemVer 2.0 semantics. | Yes — `LabelRegEx`/`LabelUnitRegEx` explicitly allow dot-separated identifiers (`(?:\.(?:...))*`). | Yes (SemVer sense), even though PowerShellGet modules can't legally publish it. |
| 4 | `1.0.0-beta+build.5` | NuGet/SemVer-2.0 shape with build metadata; not a valid PowerShellGet module Prerelease tag (`+` forbidden per the doc quoted in row 3) but valid generic SemVer 2.0.0, https://semver.org/#spec-item-10, and valid NuGet syntax, https://learn.microsoft.com/en-us/nuget/concepts/package-versioning#semantic-versioning-200 ("package version to be SemVer v2.0.0 specific if … The version has build-metadata"). | Yes (prerelease label present, so the build-metadata parsing bug in row below doesn't apply) — matches `LabelRegEx`. | Yes — still carries a prerelease label (`beta`); build metadata is cosmetic/ignored for precedence per SemVer §11. |
| 5 | `5-beta1` | Edge case: single numeric major component plus dash. **`SemanticVersion` accepts it** — `VersionSansRegEx`'s minor/patch are optional (`(?:\.(?<minor>\d+))?(?:\.(?<patch>\d+))?`), so `major=5` alone satisfies the numeric part, and `beta1` matches `LabelUnitRegEx`. **`System.Version` rejects it outright** — `System.Version` requires at minimum `Major.Minor` (two components) and has no concept of a prerelease suffix at all; a bare `5` or `5-beta1` fails `System.Version.TryParse`, https://learn.microsoft.com/en-us/dotnet/api/system.version.tryparse. Not a realistic PSGallery module version (ModuleVersion must have ≥2 segments per PowerShell module manifest rules), but realistic as a raw NuGet/generic SemVer tag. | Yes. | Yes (if encountered). |
| 6 | `1.2` | 2-part plain version — valid `ModuleVersion`/`RequiredVersion` shape; common for simple modules. | Yes (`minor` present, `patch` omitted). | No — no `-` present, so the PSGalleryModule.ps1 regex and `LabelRegEx`'s optional prerelease group both see no label. |
| 7 | `1.2.3` | 3-part plain version — the canonical PowerShellGet "stable" ModuleVersion shape required *in order to use* the Prerelease field (see row 1). | Yes. | No. |
| 8 | `1.2.3.4` | 4-part plain version — valid `[System.Version]`/`.psd1 ModuleVersion` shape (PowerShell module manifests allow up to 4 segments, e.g. many modules use `Major.Minor.Build.Revision`). | **No** — `VersionSansRegEx` caps at 3 numeric components; `SemanticVersion.TryParse("1.2.3.4")` fails, falling through to the `[System.Version]::TryParse` branch in `Test-PSDependExactVersion.ps1`. `System.Version` does accept up to 4 components, https://learn.microsoft.com/en-us/dotnet/api/system.version#remarks. | No. |
| 9 | `1.2.3.4-beta1` | 4-part version with a dash suffix — **not a legal shape for either type.** PowerShellGet's own Prerelease feature requires exactly 3 segments before the hyphen (row 1's doc quote: "may only be specified when the ModuleVersion is 3 segments"), so the Gallery itself cannot produce this as an exact `RequiredVersion`. `SemanticVersion.TryParse` fails (4 numeric components exceeds `VersionSansRegEx`'s 3-component cap, and `VersionSansRegEx` doesn't even have a dash/label group — that's handled by a separate pass in `SemanticVersion.TryParse`, but the leading numeric part still fails first). `System.Version.TryParse` also fails (it has no prerelease-suffix syntax at all — any non-digit/non-dot character after the numeric parts is invalid, https://learn.microsoft.com/en-us/dotnet/api/system.version.tryparse). PSDepend's existing regex (`^\d+(\.\d+){1,3}-[0-9A-Za-z][0-9A-Za-z\.-]*$`) *does* match this string (1-4 numeric groups then a dash) even though neither parser can confirm it's a real version — a gap worth noting if the regex is reused as a general "exact version" validity check rather than purely a prerelease heuristic. | No (as noted, matches PSDepend's current ad hoc regex but not SemanticVersion). | Debatable/edge case — looks like a prerelease marker but is not a producible real Gallery version; a human maintaining a lockfile by hand *could* still type this expecting a warning. |
| 10 | `[1.0.0,2.0.0)` | NuGet range syntax (mixed inclusive-min/exclusive-max), explicitly valid per the NuGet versioning doc's range table (`[1.0,2.0)` → "Mixed inclusive minimum and exclusive maximum version"), https://learn.microsoft.com/en-us/nuget/concepts/package-versioning#version-ranges. This is a **range**, not an exact version — `$versionRange.IsExact` will be `$false` in `PSGalleryModule.ps1`, so the prerelease-detection branch (`if ($versionRange.IsExact) { ... }`) never runs for it; `ConvertFrom-VersionRange` handles it before the regex is ever evaluated. | N/A — never reaches `SemanticVersion.TryParse` or the prerelease regex in the current code path (range, not exact version). | N/A. |
| 11 | `latest` | The sentinel PSDepend/PowerShellGet use for "no explicit version" — `PSGalleryModule.ps1` special-cases `$Version -and $Version -ne 'latest'` before even calling `ConvertFrom-VersionRange`, so it never reaches the prerelease check. Confirmed in the current script: `if ($Version -and $Version -ne 'latest') { $versionRange = ConvertFrom-VersionRange ... }`. | N/A — literal non-numeric string, would fail both parsers if tried, but the code never tries. | N/A — but `PSGalleryModule.ps1` has separate, pre-existing handling: "If specified along with version `latest`, a prerelease will be selected if it is the latest version" (comment-based help), so prerelease-ness of "latest" is resolved remotely via `-AllowPrerelease`, not via this regex. |
| 12 | `1.0.0-0` | Realistic edge case not in the original list: all-numeric prerelease identifier with a single digit. SemVer forbids leading zeros in numeric identifiers but allows a bare `0`. Valid NuGet/SemVer 2.0 prerelease (`0` matches SemVer's numeric-identifier grammar, https://semver.org/#spec-item-9), and valid PowerShellGet-module Prerelease tag (digits are within `[0-9A-Za-z-]`). | Yes — `LabelUnitRegEx`'s numeric alternative is `(?:0|[1-9]\d*|...)`, and a bare `0` is explicitly allowed as the first alternative. | Yes. |
| 13 | `1.0.0-01` | Realistic edge case: **leading-zero numeric prerelease identifier.** SemVer 2.0 spec explicitly disallows this ("Numeric identifiers MUST NOT include leading zeroes", https://semver.org/#spec-item-9). | **Rejected** by `SemanticVersion` — `LabelUnitRegEx`'s numeric branch is `0|[1-9]\d*`, which cannot match `01` (not `0` exactly, and `[1-9]\d*` requires a non-zero leading digit); the alphanumeric branch `\d*[a-zA-Z-][0-9a-zA-Z-]*` also can't match `01` (no letter/hyphen present). So `TryParse` fails, falling through to `System.Version` (which also fails, since `-01` isn't valid `System.Version` syntax) — `Test-PSDependExactVersion` would return `$false` for `1.0.0-01` even though it visually looks like a prerelease version a human typed. PSDepend's own regex (`[0-9A-Za-z\.-]*` after the first char) **does** still match it and would warn, which is arguably the more useful behavior here since it's "SemVer-shaped but technically invalid." | Yes, in the loose sense that a human reading `1.0.0-01` would expect prerelease warning treatment, even though strict SemVer/`SemanticVersion` reject it. |

### Summary of PSDepend-regex vs. `SemanticVersion` divergence

The current ad hoc regex in `PSGalleryModule.ps1`
(`'^\d+(\.\d+){1,3}-[0-9A-Za-z][0-9A-Za-z\.-]*$'`) is **looser** than `SemanticVersion`
in two ways relevant to extraction into a shared helper:

1. It accepts **4 numeric components** (`{1,3}` repetitions of `\.\d+` after the first
   `\d+` = up to 4 total), matching `System.Version`'s range, not `SemanticVersion`'s
   3-component cap (row 8/9 above).
2. It accepts **any** label after the first alphanumeric character
   (`[0-9A-Za-z\.-]*`, unanchored to SemVer's per-identifier grammar), so it does **not**
   reject SemVer-invalid shapes like leading-zero numeric identifiers (`1.0.0-01`, row
   13) or empty dot-separated segments (`1.0.0-beta..1`) that `SemanticVersion` would
   reject. This is arguably *correct* for a "does this look like a prerelease, should we
   warn" heuristic (false positives here are harmless — just an extra warning), but it is
   **not** a drop-in replacement for `[SemanticVersion]::TryParse` as a general version
   *validity* check, and the two should not be conflated when the regex is extracted.

---

## Sources consulted

- https://learn.microsoft.com/en-us/powershell/gallery/concepts/module-prerelease-support (module Prerelease tag format, `-AllowPrerelease` requirement history)
- https://www.powershellgallery.com/packages/PowerShellGet/2.2.5/Content/PowerShellGet.psd1 (PowerShellGet `ReleaseNotes`, version-by-version changelog including 1.6.0 "Prerelease Version Support")
- https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/usecompatibletypes (primary evidence `SemanticVersion` is absent from Windows PowerShell 5.1 inbox)
- https://github.com/PowerShell/PowerShell/blob/master/src/System.Management.Automation/engine/PSVersionInfo.cs#L337-L340 (`SemanticVersion` parsing regexes, source of truth for grammar)
- https://github.com/PowerShell/PowerShell/issues/14605 (build-metadata-without-prerelease-label parsing bug/history)
- https://github.com/PowerShell/PowerShell/blob/master/CHANGELOG/6.0.md (SemanticVersion constructor relaxation, `semver` type accelerator, SemVer 2.0 compatibility work — version-by-version)
- https://semver.org/spec/v2.0.0.html (SemVer 2.0.0 spec, prerelease/build-metadata identifier grammar, §9–§11)
- https://learn.microsoft.com/en-us/nuget/concepts/package-versioning (NuGet version ranges table, SemVer 2.0.0 support notes)
- https://learn.microsoft.com/en-us/dotnet/api/system.version (`System.Version`/`TryParse` grammar — 2 to 4 numeric components, no prerelease suffix support)
- https://github.com/PowerShell/PowerShellGetv2/issues/607 (dup of #561; prerelease-string validation character-set discussion)
- Local repo: `git show 072d776` (`PSDepend/PSDependScripts/PSGalleryModule.ps1`) — the `ContainsKey('AllowPrerelease')` guard's introducing commit and diff
- Local repo: `PSDepend/PSDependScripts/PSGalleryModule.ps1` (current source, lines ~150-350) — generic parameter filter loop, `ConvertFrom-VersionRange`/`IsExact` gating, `latest` short-circuit
- Local repo: `PSDepend/Private/Test-PSDependExactVersion.ps1` — existing `SemanticVersion` → `System.Version` fallback pattern
- Local repo: `docs/PSDependScripts-ReviewerChecklist.md` — existing documented version-comparison convention (cited, not restated)
