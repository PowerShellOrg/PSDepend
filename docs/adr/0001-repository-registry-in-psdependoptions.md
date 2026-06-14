# Repository auto-registration via PSDependOptions.Repositories

Private repository URLs belong in a file-level `Repositories` block inside `PSDependOptions`, not repeated per-Dependency. When a DependencyScript encounters an unregistered repository name, it looks up that name in `PSDependOptions.Repositories`, registers it persistently as Trusted, and proceeds — making the DependencyFile portable to any machine without manual setup.

## Considered Options

**Per-Dependency `RepositoryUrl` parameter** — the URL travels with each Dependency that uses it. Simpler for single-module cases but forces repetition when multiple Dependencies share a source, and scatters URL maintenance across the file.

**Ephemeral registration** (register before install, unregister after) — leaves no trace on the machine. Rejected because it re-registers on every run when many Dependencies share a source, and teardown on error paths is difficult to make reliable across three different registration APIs.

## Consequences

- `PSDependOptions.Repositories` is a new public key in the DependencyFile schema. Existing files are unaffected (the key is optional).
- Registration is persistent: the repository stays registered after PSDepend runs. This is intentional — machines in CI or shared environments accumulate registrations over time rather than re-registering on each run.
- `Test` action never registers anything; registration is gated on `Install`.
- If a repository name is already registered with a different URL, PSDepend warns but proceeds using the existing registration.
