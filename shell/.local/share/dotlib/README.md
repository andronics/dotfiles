# dotlib

Personal zsh helper library. Lives at `${XDG_DATA_HOME:-$HOME/.local/share}/dotlib` (the dispatcher fragment at `shell/.config/zsh/.zshenv.d/10-dotlib` exports `${DOTLIB}` so callers can use that).

Modules expose business logic; thin wrappers in `~/.local/bin/` route subcommands to those modules. This document is the **contract** between the two halves.

## Wrapper contract

A `~/.local/bin/<noun>` wrapper:

1. Is **≤30 lines**.
2. Starts with `#!/usr/bin/env zsh` and `set -e`.
3. Sources `${DOTLIB}/_dispatcher` and one `${DOTLIB}/_<module>` (the module name usually matches the wrapper noun; can differ — see `--prefix`).
4. Calls `dispatcher-init "<noun>" --route=function [--prefix=<other>] [--version=<v>] [--description=<d>]`.
5. Calls `dispatcher-execute "$@"`.
6. May register aliases (`dispatcher-register-alias`) and pre/post hooks (`dispatcher-before` / `dispatcher-after`).
7. Contains **no business logic**. If the file grows past 30 lines, logic has leaked — push it back into the module.

### Example — `bt` on the contract

```zsh
#!/usr/bin/env zsh
set -e
source "${DOTLIB}/_dispatcher" || { echo "missing _dispatcher" >&2; exit 1; }
source "${DOTLIB}/_bluetooth"  || { echo "missing _bluetooth"  >&2; exit 1; }

dispatcher-init "bt" \
    --route=function \
    --prefix=bluetooth \
    --description="Bluetooth control"

dispatcher-register-alias "ls"   "devices-list"
dispatcher-register-alias "scan" "scan-start"

dispatcher-execute "$@"
```

Routing:
- `bt connect aa:bb:cc` → `bluetooth-connect aa:bb:cc`
- `bt ls` → `bluetooth-devices-list` (via alias)
- `bt help` → auto-generated help (or `bluetooth-help` if defined)

## Module contract

A `${DOTLIB}/_<noun>` module:

1. Shebang `#!/usr/bin/env zsh`. Source guard near the top:
   ```zsh
   [[ -n "${<NOUN>_LOADED:-}" ]] && return 0
   declare -gr <NOUN>_LOADED=1
   ```
2. Sources its dependencies:
   ```zsh
   source "${DOTLIB}/_common" || { echo "[ERROR] _<noun> requires _common" >&2; return 1; }
   source "${DOTLIB}/_log"    2>/dev/null || true   # optional
   ```
3. **Public functions** named `<prefix>-<sub>` (e.g. `bluetooth-connect`, `bluetooth-devices-list`). `<prefix>` matches the wrapper's `--prefix` flag (default = wrapper name). Subcommand names may contain hyphens (`devices-list`, `audio-profile-set`).
4. **Private helpers** prefixed with an underscore (`_<prefix>-...`) — excluded from dispatcher discovery.
5. **Optional** descriptions for help output:
   ```zsh
   typeset -gA _<UPPER_PREFIX>_DESCRIPTIONS=(
       [connect]      "Connect to a paired device"
       [devices-list] "List all known devices"
   )
   ```
   The dispatcher uppercases the prefix and replaces hyphens with underscores when looking up this array. Absence of the array is fine; help just lists names.
6. **Optional** override functions:
   - `<prefix>-help` — replaces the auto-generated help.
   - `<prefix>-version` — replaces the auto-generated version.
   - `<prefix>-self-test` — invoked when user runs `<cmd> self-test`.
   These three names are excluded from the auto-discovered subcommand list.

## Dispatcher API (function mode)

| Call | Purpose |
|---|---|
| `dispatcher-init <name> --route=function [--prefix=<p>] [--version=<v>] [--description=<d>]` | Initialise. `--prefix` defaults to `<name>`. Idempotent — safe to call again to re-bind. |
| `dispatcher-execute "$@"` | Auto-parse global flags, resolve aliases, route `<sub>` → `<prefix>-<sub>` function call. |
| `dispatcher-register-alias <alias> <real>` | Map a shorthand to a real subcommand name. |
| `dispatcher-before <fn>` | Register a function called before each subcommand: `fn <command> <args...>`. |
| `dispatcher-after <fn>` | Register a function called after each subcommand: `fn <command> <exit_code> <args...>`. |

### Built-in subcommands

Auto-handled — do not define module functions with these names:

- `help`, `--help`, `-h` — show auto-generated help (or `<prefix>-help` if defined).
- `version`, `--version` — show version (or `<prefix>-version` if defined).
- `commands`, `list-commands` — list subcommands with descriptions.
- `completion <shell>` — emit bash or zsh completion script.

### Global flags

Auto-consumed from the front of `$@` by `dispatcher-execute`:

| Flag | Effect |
|---|---|
| `--verbose` / `-v` | `DISPATCHER_VERBOSE=true` |
| `--quiet` / `-q` | `DISPATCHER_VERBOSE=false` |
| `--debug` | `DISPATCHER_DEBUG=true` |
| `--dry-run` | `DISPATCHER_DRY_RUN=true` — dispatcher logs the would-be call instead of running it |

Module functions can read these via `dispatcher-is-verbose`, `dispatcher-is-debug`, `dispatcher-is-dry-run`, or by reading the `DISPATCHER_*` env vars directly.

## Routing modes

| Mode | Discovery | Use when |
|---|---|---|
| `function` (the contract) | Walks the function table for `<prefix>-*` | Almost always — keeps logic in the module, single file per noun in `~/.local/bin`. |
| `file` (legacy/default) | Globs `${BIN_DIR}/${NAME}-*` executables | Plugin model — each subcommand its own binary, possibly a different language. Activated by omitting `--route` or passing `--route=file`. |

Pass `--route=function` explicitly. The default stays `file` so existing positional `dispatcher-init "name" /bin/path "1.0" "desc"` calls keep working unchanged.

## Module status

Most modules in this directory are infrastructure that other modules consume (`_common`, `_log`, `_lifecycle`, etc.). Only modules with a concrete `~/.local/bin/<noun>` consumer are exercised on every shell — the rest are aspirational until claimed by a wrapper. A `STATUS.md` classification (stable / draft / infra) is a separate planned change.

## Verifying a wrapper

After writing one, smoke-test:

```sh
zsh -n ~/.local/bin/<noun>          # syntax
~/.local/bin/<noun> commands         # discovery: lists <prefix>-* functions
~/.local/bin/<noun> help             # auto-generated
~/.local/bin/<noun> <sub> --dry-run  # confirm routing
~/.local/bin/<noun> bogus            # error + command list, exit 1
```
