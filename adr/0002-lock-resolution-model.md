# Lock resolution uses a flat, greedy graph

## Context

PSDepend DependencyScripts install several package ecosystems. A Lock needs a
portable identity and resolution model without reproducing every package
manager's native graph algorithm.

## Decision

A Lock belongs to one DependencyFile and uses `DependencyType::Name` as package
identity. It records one exact version for that identity across the file.
Resolution selects the highest version satisfying the constraints currently
known, intersects constraints from every parent, and re-resolves invalidated
children until reaching a fixed point. A selected version is reused only while
its combined constraint is unchanged, preserving highest-version resolution if
a constraint broadens. It does not backtrack to an older parent version. Users
must narrow a parent range when greedy selection hides a valid older solution.

Source and DependencyScript Parameters affect resolution. Root entries store a
SHA-256 fingerprint of that context, without exposing its values, and a changed
fingerprint makes the Lock stale. Two roots cannot resolve the same package from
different contexts in one Lock.

Target, Tags, and other installation metadata do not affect version selection.
When applying a Lock, transitive packages are therefore materialized separately
for each root Dependency. Their DependencyName is normally `Name@Version`; an
additional root context receives a `#RootName` suffix to keep names unique.

A DependencyScript opts in by accepting the `Resolve` PSDependAction. Resolve
runs alone, must only query its source, and emits exactly one
`PSDepend.ResolvedDependency` containing Name, an exact Version, and a hashtable
of direct dependency names to ranges. Npm ranges pass through as npm semver;
multiple constraints use the shared NuGet intersection logic, so incompatible
cross-parent npm ranges fail rather than being reinterpreted.

NuGet v2 version catalogues are read to exhaustion across OData pages. Exact
prerelease requests are allowed, while `latest` and range resolution exclude
prereleases. Because PSDepend has no target-framework input, identical NuGet
dependency constraints across framework groups are collapsed and differing
constraints are rejected rather than selecting a group arbitrarily.

Lock format version 1 validates object shape, package references, names, and
exact versions before consumption. It does not record artifact URLs or content
hashes. A committed Lock must therefore be reviewed like code.

## Consequences

- Installation is deterministic for the exact versions recorded in the Lock.
- A graph with a valid solution can still fail if finding it requires parent
  backtracking.
- The same transitive package may be installed more than once when roots have
  different installation contexts.
- A changed Source or Parameters requires `Update-PSDependLock`.
- Native integrity verification remains the responsibility of each package
  manager until a later lock format records artifact hashes.
