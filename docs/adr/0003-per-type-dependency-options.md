# Per-type defaults nest inside PSDependOptions, override by whole value

## Context

Issue #42 asks for a middle tier between the global `PSDependOptions` block and a
Dependency's own values: a default scoped to one `DependencyType` (e.g. a
`Source` shared by every `Nuget` dependency but not by `Git` ones). Several
shapes were possible: a sibling top-level key, a deep-merged nested block, or
a whole-value-override nested block.

## Decision

Resolution is a three-tier cascade: per-Dependency value overrides per-type
default overrides global default. Per-type defaults live as nested hashtables
**inside** `PSDependOptions`, keyed by the `DependencyType` name, rather than a
new sibling top-level key — one place to look for a Dependency's effective
options. A `PSDependOptions` key is read as a per-type block only when its
value is a hashtable and its name is not one of the fixed scalar option names
(`Source`, `Target`, `Parameters`, `AddToPath`, `Tags`, `DependsOn`,
`PreScripts`, `PostScripts`, `Credential`); those names are reserved and
therefore unavailable as custom `DependencyType` names.

Override is whole-value, matching the existing `-Prefer` resolution semantics
in `Resolve-DependencyOption` (`Get-Dependency.ps1`): a type default for
`Parameters` replaces the global `Parameters` hashtable entirely rather than
deep-merging keys, so the new tier behaves exactly like the existing
per-Dependency override already does.

`Parse-Dependency` warns (non-fatal) when a per-type block names a
`DependencyType` no Dependency in the file uses — the typo/shared-name risk
the original issue raised.

Because this resolves inside `Get-Dependency`, before a parsed Dependency ever
reaches `Resolve-PSDependLock` or `Merge-PSDependLock`, no lock format change
is needed (legacy `adr/0002-lock-resolution-model.md` fingerprints the
already-resolved `Source`/`Parameters`).

## Consequences

- A `DependencyType` can never be named `Source`, `Target`, `Parameters`,
  `AddToPath`, `Tags`, `DependsOn`, `PreScripts`, `PostScripts`, or
  `Credential`.
- A type default for a hashtable-valued option (`Parameters`) is all-or-
  nothing per Dependency, consistent with today's global-vs-Dependency
  override but worth calling out since it reads like it could merge.
