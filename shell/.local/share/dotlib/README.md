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
6. May register pre/post hooks (`dispatcher-before` / `dispatcher-after`). Aliases belong in the module's `_<UPPER_PREFIX>_ALIASES` array (module contract, item 6), not in the wrapper; `dispatcher-register-alias` still works for a one-off.
7. Contains **no business logic**. If the file grows past 30 lines, logic has leaked — push it back into the module.

### Example — `bt` on the contract

The real `~/.local/bin/bt` (`shell/.local/bin/bt`). Its module is `_bluetooth_ui`, whose public functions are `bt-*`, so the default prefix (the wrapper name) fits and no `--prefix` is needed:

```zsh
#!/usr/bin/env zsh
set -e

source "${DOTLIB}/_dispatcher" || { echo "missing _dispatcher" >&2; exit 1; }
source "${DOTLIB}/_bluetooth_ui" || { echo "missing _bluetooth_ui" >&2; exit 1; }

dispatcher-init "bt" \
    --route=function \
    --description="Bluetooth CLI management tool"

dispatcher-execute "$@"
```

Routing:
- `bt connect aa:bb:cc` → `bt-connect aa:bb:cc`
- `bt devices-paired` → `bt-devices-paired`
- `bt scan-start` → `bt-scan-start`
- `bt help` → auto-generated help, described from `_BT_DESCRIPTIONS` (or `bt-help` if defined)

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
6. **Optional** command aliases, alias → real subcommand:
   ```zsh
   typeset -gA _<UPPER_PREFIX>_ALIASES=(
       [toggle]=play-pause
       [prev]=previous
   )
   ```
   Found the same way as the descriptions. `dispatcher-init` registers each entry as if the wrapper had called `dispatcher-register-alias`, so the wrapper must source the module before `dispatcher-init` (the contract order already does). Aliases route like the real name, appear in `<cmd> completion zsh` (`alias for <real>`), in `<cmd> <real> --help`'s `Aliases:` line, and `<cmd> <alias> --help` / `<cmd> help <alias>` show the real command's help. An explicit `dispatcher-register-alias` after `dispatcher-init` overrides an entry. Absence of the array is fine; a non-associative array is ignored with a warning.
7. **Optional** override functions:
   - `<prefix>-help` — replaces the auto-generated help.
   - `<prefix>-version` — replaces the auto-generated version.
   - `<prefix>-self-test` — invoked when user runs `<cmd> self-test`.
   These three names are excluded from the auto-discovered subcommand list.
   - `_<prefix>-<sub>-help` (or `<prefix>-<sub>-help`) — help for one subcommand, shown by `<cmd> <sub> --help`, `<cmd> <sub> -h` and `<cmd> help <sub>`. Without one, the dispatcher prints a usage line from the description and the aliases. Either way the subcommand itself is never run for those three forms; `--help` reaches it only when it isn't the first argument (`<cmd> <sub> -- --help`).

## Dispatcher API (function mode)

| Call | Purpose |
|---|---|
| `dispatcher-init <name> --route=function [--prefix=<p>] [--version=<v>] [--description=<d>] [--results="<codes>"]` | Initialise. `--prefix` defaults to `<name>`. `--results` lists the exit codes that are answers, not faults (the run entry's outcome is `result`, not `fail`). Idempotent — safe to call again to re-bind. |
| `dispatcher-execute "$@"` | Auto-parse global flags, resolve aliases, route `<sub>` → `<prefix>-<sub>` function call. |
| `dispatcher-register-alias <alias> <real>` | Map a shorthand to a real subcommand name. Prefer the module's `_<UPPER_PREFIX>_ALIASES` array, which `dispatcher-init` registers. |
| `dispatcher-before <fn>` | Register a function called before each subcommand: `fn <command> <args...>`. |
| `dispatcher-after <fn>` | Register a function called after each subcommand: `fn <command> <exit_code> <args...>`. |

### Built-in subcommands

Auto-handled — do not define module functions with these names:

- `help`, `--help`, `-h` — show auto-generated help (or `<prefix>-help` if defined).
- `help <sub>`, `<sub> --help`, `<sub> -h` — show that subcommand's help without running it.
- `version`, `--version` — show version (or `<prefix>-version` if defined).
- `commands`, `list-commands` — list subcommands with descriptions.
- `completion <shell>` — emit bash or zsh completion script. The zsh one defines `_<name>_cmd`; the repo keeps a copy per tool in `shell/.config/zsh/completions`, refreshed by `./dotfiles completions`.

### Global flags

Auto-consumed from the front of `$@` by `dispatcher-execute`:

| Flag | Effect |
|---|---|
| `--verbose` / `-v` | `DISPATCHER_VERBOSE=true` |
| `--quiet` / `-q` | `DISPATCHER_VERBOSE=false` |
| `--debug` | `DISPATCHER_DEBUG=true` |
| `--dry-run` | `DISPATCHER_DRY_RUN=true` — dispatcher logs the would-be call instead of running it |

Module functions can read these via `dispatcher-is-verbose`, `dispatcher-is-debug`, `dispatcher-is-dry-run`, or by reading the `DISPATCHER_*` env vars directly.

## The journal (the brain's record 0017)

Every dispatcher logs to the user journal under its own name (`journalctl --user -t <name>`), owned by `desktop-coordinator`:

- `log-warning`, `log-error` and `log-fatal` (in any `LOG_MODE`) write a `warning` or `error` entry; info, success, debug and trace never do. Messages are scrubbed of the run's arguments and redacted as the brain's `tools/journal.py` does (perl), and the same message is written at most once a minute.
- `dispatcher-execute` writes one `run` entry per run (`TOOL_COMMAND`, `EXIT_CODE`, `OUTCOME`, `DURATION_MS`, `TOOL_ACTOR` from `COORDINATOR`, `TOOL_VERSION`, `TOOL_RUN`) and one JSON line in `~/.local/state/tool-runs/<YYYY-MM>.jsonl`, never the arguments.
- `TOOL_STATS=skip` (the bar's launcher and the completions set it) writes no run entry; warnings and errors still go. `TOOL_JOURNAL=off` writes nothing; tests set it, or put a stub `logger` on `PATH` (`tests/dotlib-journal.zsh`).

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
