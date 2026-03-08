# Hermes

Native macOS command launcher (AppKit + Carbon hotkey). Replaces the old Hammerspoon webview-based version.

## Build & Deploy

```bash
make restart          # Build release, install, restart service (or: rebuild-hermes)
make build            # Build release only
make install          # Build + install binary
```

Note: `make` can be called directly from the Bash tool — no need to wrap in `fish -c` or use `-C`.

The binary is installed to `~/.local/bin/hermes` and runs as a LaunchAgent service (`org.pancia.hermes`).

Service plist: `~/dotfiles/services/hermes/org.pancia.hermes.plist`

## Config

Commands are loaded from `~/.config/hermes/commands.json` (hard-linked from `~/dotfiles/rcs/hermes-commands.json` via the dotfiles MANIFEST system). Falls back to the bundled `Config/commands.json` if the external file is missing.

Config is hot-reloaded every time the panel opens — no restart needed for command changes. Only source code changes require `rebuild-hermes`.

## Architecture

- **main.swift** — Entry point, sets up NSApplication with `.accessory` policy
- **AppDelegate.swift** — Panel lifecycle, Carbon hotkey (Cmd+Space), click-outside-to-dismiss
- **HermesPanel.swift** — NSPanel subclass (borderless, floating, rounded corners)
- **HermesViewController.swift** — Mode switching (command/search/app/window), keyboard dispatch
- **CommandMenuView.swift** — Grid layout for command items
- **Theme.swift** — Colors and layout constants
- **Services/CommandLoader.swift** — JSON parsing, generators (snippets, services, vpc)
- **Services/CommandResolver.swift** — Resolves dynamic titles via shell
- **Services/ShellExecutor.swift** — Command execution
- **Models/** — CommandEntry, CommandSpec, FlatCommand

## Modes

| Key | Mode | Description |
|-----|------|-------------|
| letter keys | Command | Navigate menu tree by key press |
| DEL | Command | Go back one level |
| `:` | Search | Fuzzy search all commands |
| `a` (root) | App | App launcher with icon grid |
| `w` (root) | Window | Yabai window switcher |
| ESC | Any | Close panel / exit mode |

## Command JSON Format

Each entry is `[title, command]`. Both title and command can be a plain string or an object:

**Command objects** — use object key to control execution mode:
- `"echo hi"` — runs in background (default), stdout/stderr discarded
- `{"shell": "vim foo"}` — opens in Ghostty, exits when done
- `{"interactive": "agenda 24"}` — opens in Ghostty, drops into interactive shell after

**Title objects** — use object key to resolve title dynamically:
- `"calendar"` — static title
- `{"shell:fish": "~/bin/get_status"}` — runs command via fish, uses stdout as title

**Examples:**
```json
"c": ["calendar", {"interactive": "agenda 24"}],
"e": ["Edit config", {"shell": "nvim ~/.config/foo"}],
"-": [{"shell:fish": "~/bin/status"}, "~/bin/reset"]
```

The canonical config is `~/dotfiles/rcs/hermes-commands.json` (hard-linked to `~/.config/hermes/commands.json`). Always edit the dotfiles version.

## Caching

Commands are cached in memory after first load. Subsequent opens show cached commands instantly, then refresh generators and dynamic titles in the background.
