# CLAUDE.md

## Build and Test

Bootstrap: `.\build.ps1 -Bootstrap`

Always run `.\build.ps1 StageFiles` before running tests — tests import from `Output\`, not source.

## Architecture

No compilation; files are staged verbatim to `Output\` — do not edit files under `Output\`.

### Extending with new dependency types

Two files must be updated together:

1. **`PSDepend/PSDependScripts/<Type>.ps1`** — handler script. Must include comment-based help and a `PSDependAction` parameter accepting `Install`, `Test`, and `Import` values.
2. **`PSDepend/PSDependMap.psd1`** — registers the type, maps it to the script, and sets `Supports` to control platform filtering (`windows`, `core`, `macos`, `linux`).

See `Git.ps1` and `PSGalleryModule.ps1` as reference implementations.

`PSDepend/PSDepend.Config` — path variables (`NuGetPath`, etc.) resolved at module load.
