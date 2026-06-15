# Version ranges use NuGet range syntax, resolved to an exact version

## Context

Issues #65 and #91 asked for version-range support (comparison operators, and
Minimum/Maximum version). The Version field has always been a single string
holding an exact version, `latest`, or `''`.

## Decision

A VersionRange is expressed in **NuGet range syntax** (`[2.2.3,3.0)`, `[2.0,)`,
`(,3.0)`) carried in the existing Version field. A string is treated as a range
only when it contains a range delimiter (`[`, `]`, `(`, `)`, `,`); a bare version
(`3.2.1`) keeps its existing exact-match meaning. There is no OR support — a
range is a single contiguous interval.

For PSResourceGet the range is passed straight to `Install-PSResource -Version`.
For PSGalleryModule and PSGalleryNuget we **resolve the range to an exact version
ourselves** (find available versions → filter with `Test-VersionInRange` → select
the maximum that satisfies → install that exact version) rather than translating
to native installer parameters.

## Considered Options

- **Named keys (`MinimumVersion`/`MaximumVersion`).** Most readable, but requires
  adding fields to the Dependency object in `Get-Dependency.ps1` and the type —
  a much larger blast radius than reusing the Version string.
- **Operator strings (`>2.2.3,<3.0`).** The comma's AND/OR meaning was ambiguous
  (flagged on #65) and there is no established grammar to point users to.
- **Strict NuGet semantics** (bare `1.0` means `>= 1.0`). Rejected: it would
  silently change the meaning of every existing requirements file.

## Consequences

- `Install-Module`'s `-MinimumVersion`/`-MaximumVersion` are **inclusive only** and
  cannot express the exclusive bound in `(1.0,2.0)` or `(,3.0)`. Translating a
  range to those parameters would leak excluded versions, so we deliberately
  bypass them and install an exact resolved version. A future reader should not
  "simplify" this back to native range parameters.
- Range semantics live in one place (`Test-VersionInRange`, built on a shared
  `Compare-Version` ordering primitive), not reinterpreted per installer.
- We deviate from strict NuGet, where bare `1.0` means a minimum — here it stays
  exact for backward compatibility.
