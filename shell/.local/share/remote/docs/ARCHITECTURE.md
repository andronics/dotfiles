# Remote - Architecture Documentation

## Overview

`remote` is a Google Drive mount/sync management system built on rclone. It
follows this repo's `dotlib` wrapper contract rather than a bespoke
dispatcher: a thin CLI wrapper routes subcommands to functions in a dotlib
module, and delegates as much of the actual work as possible to two existing
dotlib domain modules, `_rclone` and `_systemd`, instead of reimplementing
mount/unmount/sync/service-control logic from scratch.

This doc previously described a git-style multi-binary refactor
(`remote-mount`, `remote-sync`, ... as separate executables backed by a
`libexec/remote/` library tree) as already completed. That never happened —
only a 1072-line monolithic script ever existed on disk. This revision
describes what's actually implemented.

## Design Philosophy

### dotlib wrapper contract

Per `shell/.local/share/dotlib/README.md`:
- The wrapper (`~/.local/bin/remote`) is ≤30 lines, contains no business
  logic, and routes via `dispatcher-init --route=function` /
  `dispatcher-execute` to a module.
- `dispatcher-execute` auto-handles `help`, `version`, `commands`,
  `completion`, and global `--verbose`/`--debug`/`--quiet` flags.
- Public subcommand functions are named `remote-<sub>`; the dispatcher
  discovers them by scanning the function table for that prefix.

### Delegate over reimplement

`_rclone` (mount/unmount/move/sync/filter-file wiring) and `_systemd`
(enable/disable/restart/state) already existed in dotlib before `remote` was
split apart, so the domain-specific modules call into them instead of
shelling out to `rclone`/`systemctl` directly wherever the semantics line up.
The one deliberate exception is documented below (mount).

### Separation of concerns

- **Wrapper** (`remote`): routes commands, nothing else.
- **`_remote`**: the 15 public subcommand functions; owns the one place that
  intentionally does NOT delegate (mount).
- **`_remote_config`**: units/credentials/roots/filters JSON config model.
- **`_remote_patterns`**: unit name pattern matching (glob/comma/exact).
- **`_remote_filters`**: mediainfo-based filter evaluation engine for sync.
- **`_rclone` / `_systemd`**: shared dotlib domain modules, not specific to
  `remote`, doing the actual mount/unmount/move/service-control work.

## Directory Structure

```
shell/
├── .local/
│   ├── bin/
│   │   └── remote                    # wrapper: dispatcher-init + dispatcher-execute, nothing else
│   ├── share/
│   │   ├── dotlib/
│   │   │   ├── _remote                # public remote-<sub> functions, delegates to _rclone/_systemd
│   │   │   ├── _remote_config         # units/credentials/roots/filters JSON model
│   │   │   ├── _remote_patterns       # unit name pattern matching
│   │   │   ├── _remote_filters        # mediainfo filter evaluation
│   │   │   ├── _rclone                # generic rclone domain module (not remote-specific)
│   │   │   └── _systemd               # generic systemd domain module (not remote-specific)
│   │   ├── remote/
│   │   │   └── docs/ARCHITECTURE.md   # this file
│   │   └── systemd/user/
│   │       ├── remote-mount@.service  # Type=simple template unit
│   │       └── remote-sync@.service   # Type=oneshot template unit
└── .config/remote/
    ├── credentials.json                # OAuth credentials - tracked, git-crypt encrypted at rest
    ├── filters.json                    # sync filter rules
    ├── roots.json                      # local/remote mount roots
    └── units.json                      # unit definitions
```

## Core Components

### Wrapper (`remote`)

Sources `_dispatcher` and `_remote`, calls `dispatcher-init "remote"
--route=function`, then `dispatcher-execute "$@"`. That's the whole file.

### `_remote_config`

Loads the four JSON files once at source time from `xdg-config-dir "remote"`
and exposes typed getters (`remote-config-unit-mountpoint`,
`remote-config-unit-drive-id`, `remote-config-credentials-for`, ...) plus a
generic `remote-config-query <domain> <jq filter>` escape hatch for the
dynamic-index queries filter evaluation needs. Also owns
`remote-config-render-rclone-conf <unit>`, which renders an rclone.conf
`[unit]` stanza from `units.json` + `credentials.json`. This stays
custom rather than calling `_rclone`'s `rclone-create-remote`, because that
function shells out to the interactive `rclone config` TUI — unsuitable for
unattended, multi-account mounts driven by systemd at login.

(All functions in this module are named `_remote-config-*`, with a leading
underscore. That's not the "private helper" convention from the wrapper
contract in the usual single-file sense — it's there so the dispatcher's
function-table scan for the `remote-*` prefix, used to build `remote`'s
subcommand list, doesn't pick up library functions as if they were CLI
verbs. Same reasoning applies to `_remote_patterns` and `_remote_filters`.)

### `_remote_patterns`

One function, `remote-patterns-match-units <pattern>`, supporting glob
(`video-*`), comma-separated (`audio,video`), exact match, or an empty
pattern (matches everything). Used by every `*-all` subcommand plus `list`
and `verify`.

Pattern matching against a variable in zsh's `[[ ]]` requires the `${~var}`
glob-subst form — `[[ "$x" == $pattern ]]` does **not** glob-expand a pattern
held in a variable by default, it compares literally. The original script
didn't do this, so `remote list` (default pattern `*`) and any glob pattern
passed to any `*-all` command silently matched nothing. Fixed here.

### `_remote_filters`

`remote-filters-evaluate` (the `eq`/`ne`/`lt`/`le`/`gt`/`ge`/`in` comparator)
and `remote-filters-check-file` (looks up a pattern's rules from
`filters.json`, extracts `mimetype` via `file` or audio/video properties via
`mediainfo`, evaluates every rule). This is the only schema supported today —
an older, differently-shaped `filters.json` and its validator existed before
this rewrite and are gone (they were unreachable from the dispatcher
already). The file was briefly named `filters2.json` during the transition
to disambiguate from that removed legacy schema; renamed back to
`filters.json` once there was nothing left to disambiguate from.

### `_remote`

The 16 subcommand functions, grouped below. `--dry-run` and `--preview` are
**local, per-subcommand flags** read from the subcommand's own arguments
(`remote mount --dry-run <unit>`), not dispatcher's global `--dry-run`. See
"Dry-run Mode" for why.

## Subcommands

| Subcommand | Delegates to | Notes |
|---|---|---|
| `mount <unit>` | *(not delegated — see below)* | Foreground `rclone mount`, same tuning flags as before |
| `unmount <unit>` | `rclone-unmount` | fusermount→umount fallback |
| `mount-all [pattern]` | `systemd-start "remote-mount@<unit>"` | Not synchronous in-process — see below |
| `unmount-all [pattern]` | `systemd-stop "remote-mount@<unit>"` | |
| `sync [--preview] <unit>` | `rclone-set-config`, `rclone-set-filter-file`, `rclone-move` | Scan/filter/preview logic stays in `_remote` |
| `list [pattern]` | `systemd-get-state` | Table of unit/mountpoint/status/cache size |
| `verify [pattern]` | `rclone-is-mounted` | Config sanity + mount-state check (read-only) |
| `health [pattern]` | `rclone-is-mounted`, `systemd-restart` | Liveness sweep for enabled units; restarts what's unhealthy — see below |
| `cleanup [--force]` | `rclone-is-mounted` | Stale runtime config / empty cache cleanup |
| `enable <unit>` | `systemd-enable-start` | |
| `disable <unit>` | `systemd-disable-stop` | |
| `restart <unit>` | `systemd-restart` | |
| `enable-all` / `disable-all` / `restart-all [pattern]` | loop over the singular functions above | Safe: none of these hold a foreground process |
| `status` | direct `systemctl --user list-units "remote-mount@*"` | No `_systemd` equivalent for a glob-filtered listing |

### Why `mount` doesn't delegate to `_rclone`

`_rclone`'s `rclone-mount` always runs `rclone mount ... --daemon`, which
forks into the background and returns immediately. `remote-mount@.service`
is `Type=simple`, which requires `ExecStart` to stay in the foreground as the
tracked process — that's what makes `Restart=on-failure` and a clean
`ExecStop` work. Delegating would make the service exit immediately after
starting the real mount, defeating systemd's supervision. `remote-mount`
therefore builds its own foreground `rclone mount` invocation directly,
unchanged in spirit from the original script.

### Why `mount-all`/`unmount-all` don't call the singular functions in-process

`remote-mount` blocks in the foreground for the lifetime of the mount (see
above). A synchronous loop calling `remote-mount` for multiple units would
hang forever after the first one. Bulk mount/unmount instead triggers the
systemd template unit per matched name, so each mount is its own supervised
process. This is different from `enable-all`/`disable-all`/`restart-all`,
which safely loop over their singular counterparts since those are
non-blocking systemctl calls.

### Why `health` is a separate function from `verify`

`remote-verify` is read-only by design — it's also used as
`remote-mount@.service`'s `ExecStartPre` gate, so it must never have
side effects. `remote-health` is the mutating counterpart: driven by
`remote-healthcheck.timer` (every 10 minutes), it only looks at units whose
`remote-mount@<unit>.service` is currently systemd-enabled (the actual
"should be running" signal, not just present in `units.json`), and restarts
anything unhealthy via `systemd-restart`.

"Healthy" is checked two ways, not one: `rclone-is-mounted` only confirms the
kernel mount table has an entry — a wedged FUSE endpoint (network drop,
revoked token) still passes that check while actual I/O hangs. A bounded
`timeout --kill-after=5s 10s stat <mountpoint>` catches that case. Note
`timeout` can't guarantee killing a process stuck in uninterruptible sleep
(D-state) on a truly wedged FUSE mount — the per-unit timeout is scoped
inside the sweep loop specifically so one stuck probe can't block the rest
of the sweep, even in that worst case.

No consecutive-failure backoff — a persistently broken unit (e.g. revoked
OAuth grant) gets a restart attempt every 10 minutes indefinitely. Considered
and deliberately skipped for now; add it later if it turns out to matter in
practice.

## Configuration Files

### units.json / roots.json / filters.json

Unchanged from before — see the JSON examples inline in each file. No schema
changes.

### credentials.json

OAuth credentials for Google Drive API, keyed by account name, holding live
`client_id`/`client_secret`/`token`. Gitignored (`**/credentials.json` in the
repo root `.gitignore`) — never commit this file. Keep both the file
(`600`) and its containing directory (`700`) locked to the owning user; there
is no reason for either to be group/world readable.

### sandbox.json

Not implemented. The original script had a `sandbox` subcommand that just
toggled the (already-broken) dry-run global and recursively re-invoked
itself — removed as dead code. If sandbox mode is wanted later, design it
against the current dispatcher's own `--dry-run` handling rather than
resurrecting the old recursive-toggle approach.

## Dry-run Mode

**Not** wired through `_dispatcher`'s global `--dry-run` flag. In
function-mode routing, `dispatcher-execute-command` treats
`DISPATCHER_DRY_RUN=true` as all-or-nothing: it skips calling the subcommand
function entirely and just logs `[DRY RUN] Would call: <fn> <args>`. That
would lose the informative per-command output this module already produces —
most notably `sync`'s file-by-file preview listing.

Instead, `--dry-run` is a **local flag** read by the subcommand itself,
placed right after the subcommand word:

```bash
remote mount --dry-run <unit>
remote sync --dry-run <unit>       # equivalent to --preview for sync
remote cleanup --dry-run
```

This mirrors `sync`'s pre-existing `--preview` flag, which uses the same
placement convention. (This is a change from the old syntax,
`remote --dry-run <command>`, which is no longer meaningful — that form now
triggers dispatcher's coarse global skip instead of the graceful per-command
dry-run behavior.)

## Pattern Matching

Unchanged behavior, now actually working (see `_remote_patterns` above):

```bash
remote mount-all video-*        # glob
remote list audio,video          # comma-separated
remote enable-all *              # everything
remote verify *-backup           # glob
```

## Systemd Integration

`remote-mount@.service` is the `Type=simple` template unit
(`ExecStartPre=remote verify %i`, `ExecStart=remote mount %i`,
`ExecStop=remote unmount %i`), started via `WantedBy=default.target` and kept
alive by `Restart=on-failure`; it has no timer. `remote-sync@.service` is
`Type=oneshot` (`ExecStart=remote sync %i`), driven entirely by
`remote-sync@.timer` (every 4h) since nothing else would ever run it, and now
also gated by `Requisite=`/`After=remote-mount@%i.service` so it fails fast
if the mount isn't active rather than racing a dead mountpoint.

A `remote-mount@.timer` existed previously (same 4h schedule, description
copy-pasted from the sync timer) but had no real purpose beyond what
`Restart=on-failure` already covers and was never documented — removed.

`remote-healthcheck.service` (oneshot, `ExecStart=remote health`, not
templated — sweeps every enabled unit in one run) is driven by
`remote-healthcheck.timer`: `OnBootSec=2min` / `OnUnitActiveSec=10min`, a
fixed interval (an env-configurable interval was attempted first, but
`[Timer]` sections can't read `Environment=`/`EnvironmentFile=` — those only
apply to `[Service]` — so making it configurable would have meant either a
foreground-loop daemon instead of a timer, or a self-throttling stamp file;
skipped as not worth the complexity for now). This is what actually catches
a wedged-but-still-running mount, which neither `Restart=on-failure` nor the
old `remote-mount@.timer` could. See "Why `health` is a separate function
from `verify`" above for the mechanism.

```bash
systemctl --user start remote-mount@audio
systemctl --user enable remote-mount@audio
systemctl --user status remote-mount@audio
```

## Extension Points

### Adding a new subcommand

Add a `remote-<name>` function to `_remote`, optionally with a
`_REMOTE_DESCRIPTIONS[<name>]="..."` entry for `remote help`. No new files
needed unless the logic is substantial enough to warrant its own sibling
module (follow the `_remote_config`/`_remote_patterns`/`_remote_filters`
pattern: leading-underscore function names so the dispatcher's `remote-*`
discovery scan doesn't expose them as top-level verbs).

### Adding new configuration

Add the JSON file under `.config/remote/`, load it in `_remote_config`
alongside the existing four, expose typed getters as needed.

## Future Enhancements

- Sandbox mode, designed against `_dispatcher`'s own dry-run/flag handling
  rather than the old recursive-toggle approach.
- Remote-to-remote sync.
- Cache size quotas (mount health monitoring is now handled by `remote
  health` / `remote-healthcheck.timer` — see Systemd Integration).
- Parallel bulk mount (currently sequential per matched unit).
- Consecutive-failure backoff for `remote-health`, if restarting a
  persistently broken unit every 10 minutes turns out to be a problem in
  practice.

---

**Author**: Andronics
