# Add-PSDepend writes DependencyFiles via hand-rolled AST insertion, not PoshCode/Metadata, and auto-updates the lock

Status: accepted

`Add-PSDepend` (issue #26) needs to add a new entry to a `DependencyFile` (`requirements.psd1`/`*.depend.psd1`) without destroying hand-written formatting or comments elsewhere in the file. The original 2017 issue thread recommended building this on `PoshCode/Metadata`'s `Import-Metadata`/`Export-Metadata`. On inspection, `Export-Metadata` fully re-serializes the entire file through `ConvertTo-Metadata` on every call — it reformats *every* existing entry, not just the new one, so comments are lost repo-wide rather than preserved for untouched entries. `Update-Metadata` avoids the full rewrite but its own doc comment states it cannot create new keys, only overwrite an existing uncommented value — unusable for appending a dependency.

We decided `Add-PSDepend` parses the target file with the PowerShell AST to locate the insertion point and splices in only the new entry's text as a plain append before the closing brace, leaving the rest of the file byte-for-byte untouched, with no dependency on `PoshCode/Metadata`. New entries are written as a terse string (`'Name' = 'Version'`) when only Name and Version were given, or a full hashtable otherwise; the psd1 key is always the bare `Name` (not the `DependencyType::Name` disambiguation form), so adding a same-named dependency of a different type is treated as a collision like any other and requires `-Force`.

We also decided `Add-PSDepend` auto-runs `Update-PSDependLock` after a successful write (so the repo is never left in the stale-lock state `Merge-PSDependLock` already detects and errors on), with a `-NoLock` switch to opt out for offline/CI use, and rolls back the file write if the lock step fails.

## Considered Options

- **Full rewrite via `Export-Metadata`**: simplest implementation, but reformats the whole file and drops comments on every `Add-PSDepend` call — rejected for destroying user-authored formatting outside the one entry being added.
- **Hybrid**: depend on `PoshCode/Metadata` only for `ConvertTo-Metadata` to render the new entry's value, still splice via AST ourselves — rejected in favor of no new dependency at all, since AST insertion alone is sufficient for the value shapes PSDepend's DependencyFile schema actually uses.
- **Leave the lock alone / warn-only after writing**: keeps `Add-PSDepend` network-free, but reintroduces the staleness problem `Update-PSDependLock` was built to catch — rejected in favor of auto-updating with an explicit opt-out.

## Consequences

- No new runtime dependency for PSDepend.
- `Add-PSDepend` performs a network call (dependency resolution) by default, which is surprising for a command whose name suggests "edit a file" — mitigated by `-NoLock` and documented explicitly.
- Files containing comments or custom formatting are only safe from reformatting because insertion is append-only; a future change to support re-sorting or in-place updates of existing entries would need the same AST-preserving discipline, not a drop-in `Export-Metadata` call.
