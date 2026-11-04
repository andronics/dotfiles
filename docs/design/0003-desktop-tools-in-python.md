# 0003: Desktop tools move to Python; barctl masters the bar

Status: Approved (by Stephen for question 1; by the brain coordinator, on Stephen's behalf, for everything
else; 2026-11-04)
Date: 2026-11-04
Authors: Stephen Cox (direction); written up by the desktop coordinator

This record amends one choice in record 0001 (Polybar IPC module taxonomy): its question 1 decided that the
bar controller is "one shared controller, in zsh as a `dotlib` module with a thin dispatcher". This record
moves the controller, and in time every desktop tool, to Python. Everything else record 0001 decided stands:
`custom/ipc` modules, one render hook (`hook-0`) per module, the colour tiers, `barmenu` (rofi) right-click
menus, the player selection rule, the availability table (with two corrections from new evidence, in Part
B), the aggregate counter's four sources and its GraphQL budget. Where this record differs, it says why.

## Context

### Stephen's direction

On 2026-11-04 Stephen directed, through the brain coordinator, that our tooling moves from the dotfiles' zsh
library (`dotlib`) to Python, in line with the platform templates, and that the bar controller `barctl` is
rebuilt in Python now, as the master of everything Polybar. The brain's 📐 Tooling Conventions note already
records the rule: new tools are Python, started from template-python; existing dotlib tools move over
most-used first, keeping their names and flags; desktop tools live together in one package,
andronics/desktop-tools, owned by the desktop coordinator, with only config and thin shims left in the
dotfiles.

### What exists today

- **The zsh bar controller** (`shell/.local/share/dotlib/_barctl`, merged 2026-11-04 in PR 73, "event-driven
  bar controller with volume and player"). `barctl run` runs from `barctl.service` (a systemd user unit
  started by `.zlogin.d/50-barctl`, never by polybar). It has two sources: volume (`pactl subscribe`, drawing
  `audio-level`) and players (`playerctl -a --follow`, drawing `player-play-pause` and `player-metadata`).
  Each writes `<tier><TAB><text>` to `~/.local/state/barctl/<module>` and pokes the module only when that
  changed; the module's hook, `barctl render <module>`, reads the file and colours it from the theme's roles.
  Its verbs are `run`, `render`, `poke` and `status`. Outside programs cannot give it state: there is no
  `push`.
- **Its known gap:** clicks on the player modules run `player play-pause` and friends, which act on
  playerctl's default player, not on the player the bar is showing.
- **Other programs talk to polybar directly.** `grep -rn polybar-msg` finds these callers outside the
  controller (full list: the PR's evidence, `polybar-msg-callers.txt`):

  | Caller | What it sends | Why |
  |---|---|---|
  | `_coord` (`_coord-poke`, line 361) | `polybar-msg action coord hook 0` | redraw the coordinator strip after show, hide, launch or a state change |
  | `_bsp` (`_bsp-polybar-toggle`, line 810) | `polybar-msg cmd hide` / `cmd show` | `bsp-hide` / `bsp-unhide` hide the bar with the windows |
  | `_theme` (`_theme-reload-polybar`, line 1949) | `polybar-msg -p <pid> cmd restart` | restart each bar on a new theme, with frozen-bar detection and relaunch |
  | `_theme` (`_theme-polybar-ping`, line 1986) | `polybar-msg -p <pid> action '#theme-ping.ping'` | check that a restarted bar answers |
  | `polybar-reload` (via `theme reload polybar`) | as `_theme` | restart the bars, or start one when none is running |

  The tests (`tests/barctl.zsh`, `tests/coordinators.zsh`, `_theme`'s self-test) stub `polybar-msg`; they are
  not callers.
- **The brain's records this ties into** (in the vault's decisions folder, all approved):
  - brain record 0016, "Actors run root commands only through an allowlisted wrapper": nothing here needs
    root, and nothing here may.
  - brain record 0017, "Tools log errors and runs to the journal for their owners": every tool logs warnings,
    errors, uncaught exceptions and one end-of-run entry (never its arguments) to the user journal through a
    small standard-library helper; callers that poll set `TOOL_STATS=skip`.
  - brain record 0019, "One meta command is the front door to every centre": `meta <centre> status|list|show
    [--json]`; the desktop centre's module, and the coordinator switchboard `coord` renamed `crew`, with a
    quick menu per coordinator glyph.
- **The templates** (both public). template-base gives AI-assistant instructions, the guard rails, CI with one
  required check (`ci`) and weekly template-update PRs. template-python, applied on top with `kind: cli`,
  gives `pyproject.toml` (uv, hatchling), `src/<package>/` with a Typer CLI and a settings module on the
  `interpose` engine, `ruff`, `mypy --strict`, `pytest` with an 80% coverage floor, CI that tests the minimum
  Python version and every newer one, release-please releases, and a wiki generated partly from the Typer
  app (`scripts/gen-wiki.py` walks it for the CLI reference). It asks for a minimum Python of 3.13 or 3.14.
- **Measured cost of a start** (wall clock, median of seven; evidence `startup-timings.txt`): Python with
  `argparse`, `json` and `socket` imported, 24 ms; today's `barctl render audio-level` in zsh, 29 ms;
  importing Typer adds about 30 ms warm and up to about 95 ms cold. Python is no slower than zsh for the
  render hook as long as the hook avoids heavy imports.

### Why now

Before the next bar modules (printer, scanner, VPN, Bluetooth, the counter) are written, so that none of them
is written in zsh and rewritten later; and before `crew` (brain record 0019) lands, since crew's strip is the
first outside program that needs to give the bar state.

### Constraints carried over

- polybar 3.7 leaks its module pipes into long-lived children, which can freeze its next restart: nothing
  long-lived may be a child of polybar, and a click must detach what it starts.
- Colours come from theme roles at render time, never hex in a repo.
- Both repos are public: no token, account detail or host secret in either.
- Each tool keeps its name and flags: `bars/`, `modules/*.ini`, sxhkd and muscle memory don't change because
  of the move.

## Decision

### Part A: desktop tools move to Python

#### A1. One repo, one package

- **A new repo, andronics/desktop-tools**, made from template-base, then template-python with `kind: cli`,
  `container_image: no`, `integration_ci: no`. The desktop coordinator owns it (a scope change to its actor
  note, proposed to the brain coordinator as actor steward, see Open questions).
- **One Python package, `desktop_tools`, one console command per tool.** `pyproject.toml`'s
  `[project.scripts]` lists each tool under its current name: `barctl = "desktop_tools.barctl.cli:main"`,
  and later `player`, `audio`, `bt`, `theme`, `desk` and the rest. Each tool keeps its subcommands, flags,
  exit codes and output format, so the polybar config, sxhkd and anyone's habits keep working. A tool that
  changes a flag says so in its cut-over PR, with the reason.
- **Typer, as the template gives it, with a fast path.** Every tool is a Typer app, and a top-level
  `desktop-tools` app mounts each as a sub-app, so the template's wiki generator documents all of them from
  one place (`desktop-tools barctl status` and `barctl status` are the same command). The two hot verbs,
  `barctl render` and `barctl push`, are handled in `main()` before Typer is imported, with the standard
  library only, unless `-h` or `--help` is among their arguments (then Typer handles it). See Open question 3
  for the alternative.
- **Layout.** `src/desktop_tools/<tool>/` per tool (`cli.py` for the Typer app, the rest plain modules);
  `src/desktop_tools/common/` for what tools share: the journal helper, theme roles, polybar IPC, XDG paths,
  running a detached command.

#### A2. Installing: `uv tool`, from a release tag

- **Normally from a tag:** `uv tool install --python 3.13 --managed-python
  "git+https://github.com/andronics/desktop-tools@v<version>"`. release-please makes the tags; the wanted
  version is one line in the dotfiles (`desktop/.config/desktop-tools/version`), and `desktop/.postinstall`
  installs or upgrades to it, so a dotfiles commit says which tools the desktop runs and a revert rolls
  them back.
- **A uv-managed Python**, not the system one: `uv tool` venvs point at their interpreter, and a pacman
  upgrade of the system Python to a new minor version would break every command, the bar's hook included.
- **While developing:** `uv tool install --editable <checkout>` from the desktop coordinator's checkout,
  only on the coordinator's say, and never left in place after a cut-over (the tag is what the dotfiles pin).
- **Where commands land:** `uv tool`'s default, `~/.local/bin`, the same folder the dotfiles' stow links use.
  Nothing's PATH changes (polybar, sxhkd and `barctl.service` already have it), and `uv tool` refuses to
  overwrite a file it didn't install, so a tool can't be installed while its zsh wrapper is still linked:
  the cut-over PR removes the wrapper (Open question 5 has the alternative of a separate folder).

#### A3. What stays in the dotfiles

- **Config:** `desktop/.config/barctl/modules.toml` (Part B), the polybar ini files, sxhkd, the version pin,
  and every other tool's config, as today.
- **Shims, only where something sources a dotlib function.** A command on PATH needs no shim: polybar,
  sxhkd and the shell call it by name. A shim is needed only while a zsh module still calls another module's
  function in-process (for example `_theme` calling `theme-roles`, or `_coord` calling `_coord-poke`): the
  function stays in dotlib as a one-line call to the Python command until its last zsh caller moves, then
  goes. No other shims; `dotlib` is removed when it is empty.
- **Completions:** generated, in the folder the desktop coordinator owns (A6).

#### A4. Order of the move

1. `barctl` first, now (Part B), with the journal helper and the shared pieces it needs, and `barmenu` with
   it, since the controller's menus are built on it.
2. Then the other dotlib tools, most-used first, by `tool-stats` (brain record 0017's usage report) once its
   pilot has run and dotlib's `_dispatcher` writes run entries; until then, by Stephen's keys and the bar:
   `player`, `audio`, `bt`, `desk`, `crew`, `theme`, then the rest.
3. Each move is one PR in desktop-tools (the tool, its tests, its completion) and one in the dotfiles (remove
   the wrapper and module, bump the version pin), cut over together.
4. `dotlib` and `_dispatcher` go when the last module has moved.

#### A5. Python version and dependencies

- **Python:** minimum 3.13 (the template's default; CI also tests 3.14, which the desktop runs today).
- **Runtime dependencies:** the template's for a CLI (`typer`, `interpose`, `pyyaml`); beyond those, standard
  library first. A library is allowed when it replaces a long-lived subprocess or a fragile text parse, is
  pure Python or a well-maintained wheel, and has no daemon of its own. Recommendations:

  | Library | For | Recommendation |
  |---|---|---|
  | `jeepney` | D-Bus: BlueZ (Bluetooth), MPRIS players (to act on one player by name), NetworkManager | **Allow**, when the first D-Bus source lands (Bluetooth). Pure Python, small, maintained, both blocking and asyncio |
  | `dbus-next` | D-Bus | **No:** unmaintained since 2022; its fork `dbus-fast` is larger and leans on compiled code. `jeepney` covers the need |
  | `pulsectl` | PulseAudio/PipeWire volume | **Not now:** `pactl subscribe` works, needs no library, and is what the zsh controller proved. Revisit if parsing its output gives trouble |
  | `pydantic` | the state model and config | **No:** dataclasses, `tomllib` and `json` cover a dozen fields; pydantic adds about 50 to 100 ms to every start, the render hook included |

- **Config files are TOML**, read with the standard library's `tomllib`; the template's `interpose` settings
  stay for environment overrides (`BARCTL_STATE_DIR` and the like, which tests need).

#### A6. Tests, CI and completions

- **Tests and CI as the template gives them:** `pytest` with the 80% floor, `ruff`, `mypy --strict`, the
  secret scan, one required check (`ci`). Nothing in CI touches a live system: polybar IPC, `pactl`,
  `playerctl`, `lpstat`, D-Bus and the journal socket are fakes (a fake polybar socket, recorded event
  streams, a temporary datagram socket for the journal). The zsh tests' cases carry over: help runs nothing,
  every tier on every module, the player selection rule, one poke per change to the right module, a single
  controller and a clean stop.
- **Completions:** a script in desktop-tools generates one `_<tool>_cmd` file per tool from the Typer
  command tree (the way `gen-wiki.py` already walks it), in the dotfiles' style and with the "generated"
  marker the brain's generator uses, and CI fails when they are out of date (`--check`). Live values (module
  names, players) come from the tool at TAB time (`TOOL_STATS=skip barctl list`), cached for the shell's
  life, as 📐 Tooling Conventions asks. The files are installed into the dotfiles' completions folder by
  `desktop/.postinstall` from the installed package (`desktop-tools completions zsh --out <dir>`), so they
  always match the installed version. The brain's own generator, `gen-zsh-completions.py`, reads argparse
  only, so it isn't reused as is.

#### A7. `--help` never acts

Typer's `--help` is eager: it prints and exits before the command runs, at every level, so the dispatcher's
rule ("`<tool> <command> --help` shows help and never runs the command") holds by construction. The fast
path (A1) checks for `-h`/`--help` first and hands those to Typer. A test runs every command with `--help`
under fakes that fail on any call, and fails if anything was called.

#### A8. Logging to the journal (brain record 0017)

- **The helper:** a copy of the brain's `tools/journal.py` (standard library, the journal's native socket) in
  `desktop_tools/common/journal.py`, with a header naming the brain commit it was copied from, and the
  brain's test for it copied beside it (no arguments logged, the redaction cases, a missing socket changes
  nothing, exactly one run entry). Open question 6 asks whether it should instead be one shared package.
- **Fields:** `SYSLOG_IDENTIFIER` is the command name (`barctl`), `TOOL_COMMAND` the Typer subcommand,
  `TOOL_OWNER=desktop-coordinator`, `TOOL_VERSION` the installed package's version (there is no checkout to
  ask git), and the calling actor as record 0017 resolves it.
- **Result codes:** declared per tool; for `barctl`, the `meta` codes (0 ok, 1 a problem found, 5 not
  found).
- **Hot verbs:** `render` and `push` never write a run entry, whoever calls them (a render runs on every
  poke; a push on every Claude hook through crew); they still log their errors, rate-limited by the helper.
  `click` always writes its run entry, even with `TOOL_STATS=skip` inherited from polybar: one click is one
  deliberate action by Stephen, which is exactly the usage `tool-stats` exists to count.

#### A9. Public

The repo is public: nothing in it is secret (the GitHub module reads its token from the `gh` login at run
time; no host names beyond what the dotfiles already show), the dotfiles are public too, and the templates'
secret scan runs on every PR. Making a repo public is Stephen's to approve (Open question 1).

### Part B: barctl, master of everything Polybar

#### B1. One owner of polybar

`barctl` is the only program that talks to polybar: it starts and restarts the bars, sends every IPC
message, and holds every IPC module's state. Every other tool updates the bar through `barctl push` (or
`alert`); none runs `polybar-msg`, and a test in desktop-tools and one in the dotfiles fail if any file but
barctl's polybar module names `polybar-msg` or polybar's IPC socket.

barctl speaks polybar's IPC protocol itself, over each bar's socket in `$XDG_RUNTIME_DIR/polybar/`, instead
of starting a `polybar-msg` process per message; `doctor` checks the protocol version polybar answers with,
and barctl falls back to `polybar-msg` if it doesn't recognise it.

#### B2. The state a module carries

One JSON document per module, the same whether the controller's own source or an outside pusher wrote it:

| Field | Type | Meaning |
|---|---|---|
| `tier` | `unavailable` \| `idle` \| `active` \| `alert` | Record 0001's tiers, coloured at render time from the theme roles `dim`, `fg_dim`, `accent`, `urgent`. `alert` here is a steady urgent (a coordinator waiting for input); a timed blink is `alert_until` below |
| `glyph` | text | The icon (a current Nerd Font codepoint) |
| `label` | text, optional | The text beside or instead of the icon (record 0001's text fallback): `player-metadata`'s track, the VPN's country |
| `count` | integer, optional | A count shown after the glyph when above 0 (print jobs, open reviews); kept apart from the label so `status --json` and `meta` can read it as a number |
| `detail` | text, optional | A longer line for people: `show`, `status`, notifications, `meta desktop status`. polybar has no tooltips, so this never reaches the bar itself |
| `target` | text, optional | What a click acts on: the shown player's MPRIS name, the sink, the Bluetooth device's address |
| `segments` | list, optional | For a module that is several cells (crew's strip): each with its own `tier`, `glyph`, `label`, `id` and clicks. When present it replaces `glyph` and `label` |
| `alert_until` | time, optional | Set by `alert`: until then the module blinks between its tier and `urgent` |
| `source`, `updated` | text, time | Who wrote it (`volume`, `player`, `crew`) and when |

- **Text is text.** barctl escapes polybar's format tags (`%{`) in everything pushed, and writes the colour
  and action tags itself, so no pusher can put a command into a click.
- **Clicks go through barctl.** A module's action tags always run `barctl click <module> <button>` (with
  `--segment <id>` for a segment); barctl looks up what that click does (B4) and runs it detached
  (`setsid`, inherited descriptors closed), so no click can freeze the bar's next restart.
- **Display per module** (in `modules.toml`): `icon` (glyph, then count), `text` (label), or `both`.

#### B3. Where state lives, and how it survives restarts

- **Module states** live in `$XDG_RUNTIME_DIR/barctl/modules/<module>.json`, written whole and renamed
  into place. The runtime folder is memory-backed and emptied at logout, so a state from a previous session
  can never be shown as current.
- **Settings** (modules disabled, the counter's chosen source) live in `$XDG_STATE_HOME/barctl/` and
  survive logouts.
- **A polybar restart** (a theme change, `barctl restart`): `initial = 1` runs each module's hook, which
  renders from the files, as today; nothing is asked of the controller.
- **A controller restart:** on start it clears the states of its own sources' modules (they are redrawn
  within a second from live sources) and keeps pushed states.
- **A stale push:** `push --ttl <duration>` lets a pusher say how long its state holds; past it, render shows
  the module `unavailable` with its glyph. Pushers that can die without saying so (crew's hooks) use it.
- **The zsh controller's folder** (`~/.local/state/barctl/`) is not touched, so a rollback finds it as it
  left it.

#### B4. Who may write which module

`desktop/.config/barctl/modules.toml` (dotfiles, config) lists every IPC module: its `source` (one of the
controller's own: `volume`, `player`, `printer`, `scanner`, `vpn`, `bluetooth`, `counter`) or its `pusher`
(an outside program's name: `crew`), its display, its menu rows (record 0001's question 5: quick actions are
rows, dynamic rows come from the source), and its clicks (`left = ["player", "play-pause"]` with `{target}`
filled in as a whole argument). barctl refuses (exit 3) a push to a module whose source is its own or whose
pusher is someone else: one writer per module, so a source and a pusher never fight over the same icon.

A push writes the state file itself (so it works with the controller stopped), then tells the controller
over its control socket (`$XDG_RUNTIME_DIR/barctl/control.sock`, one second at most); with no controller
running, it pokes the module itself. Blinking, timers and every live source need the controller.

#### B5. The verbs

Each verb, its contract in one line, and where it differs from the brief that asked for it.

| Verb | Contract |
|---|---|
| `status [--json]` | Whether the controller is running (pid, since when), each bar alive and answering, and every module's tier, glyph, label, count, source and age; exits 0, or 1 if the controller or a bar is down or a module's source is failing. A device being off is a tier, not a failure. JSON in brain record 0019's `status` shape (`summary`, `state`, `checks`) |
| `list [--json]` | Every module name, one per line, sorted (for completion); `--json` adds source or pusher, display and enabled |
| `show <module> [--json]` | One module in detail: its state, `detail`, target, alert, writer, last change, its clicks and menu rows; exit 5 for an unknown module |
| `push <module> [--tier T] [--glyph G] [--label L] [--count N] [--detail D] [--target X] [--ttl D] [--json -]` | **The only way another tool changes the bar.** Sets the module's state (given fields replace, others keep; `--json -` reads a whole state, segments included, from stdin), and pokes it only if what it shows changed; exit 3 if the caller may not write that module |
| `alert <module> [--for <duration>] [--segment <id>]` | Blink the module (or one segment) between its tier and `urgent` until the duration ends (default 30 s; `--for 0` stops it). A second alert extends the first. Needs the controller; without it, shows a steady `urgent` until the time is up |
| `menu <module>` | Open the module's right-click menu: its rows from `modules.toml` plus the dynamic rows its source gives (VPN countries, paired devices), drawn by `barmenu` (rofi) above the module |
| `click <module> <button> [--segment <id>]` | What every action tag runs. `button` is `left`, `middle`, `right`, `scroll-up`, `scroll-down`. Runs the module's configured command for that button with `{target}` filled from the state, detached, so a player click acts on **the player the bar shows** (`player -p <name> play-pause`), fixing PR 73's gap where clicks went to playerctl's default player; `right` defaults to `menu` |
| `reload [<module>]` | Redraw: re-read `modules.toml` and the theme roles, and poke every module (or one) without restarting polybar. Replaces today's `poke` |
| `restart [<bar>]` | Restart the polybar processes in place, detect a bar that froze or exited and relaunch it from its own command line and environment (today's `_theme-reload-polybar`), or start the bar (`$POLYBAR_BAR`, else `main`) when none is running (today's `polybar-reload`). Bars are started with `TOOL_STATS=skip` |
| `theme` | Called by `theme apply`: re-read the theme roles, then `restart`, since polybar reads its ini colours only at start. Replaces `theme reload polybar` and `polybar-reload`'s use of it |
| `enable <module>` / `disable <module>` | Start or stop a module's source and show or blank it, remembered across logins (a printer that's away for a month). Does not edit `bars/main`, which is Stephen's layout |
| `watch [<module>...] [--json]` | Follow state changes as they happen, one line (or JSON line) each, until interrupted: for debugging, and for tools that want to react to the bar |
| `doctor [--json]` | Check everything barctl needs: one controller, every bar answering IPC and the protocol version, every `custom/ipc` module in the polybar config known to `modules.toml` and the reverse, each source's commands present (`pactl`, `playerctl`, `lpstat`, `nordvpn`), the theme roles readable, the state folders writable, no stale or orphan states; each with a fix to try. Exit 1 on any problem |
| `run` | The controller, run by `barctl.service`: one at a time (a lock), every enabled source as a thread or subprocess reader, the control socket, alert timers; exits non-zero if a source can't be restarted, for systemd to restart it |
| `render <module>` | A module's `hook-0`: print its current text with colour and action tags, from the state file and the theme roles, in a few tens of milliseconds; prints an empty line, never an error, when anything is missing |
| `hide` / `unhide` (added) | Hide or show the bars (`bsp-hide` / `bsp-unhide` call them instead of `polybar-msg cmd hide/show`). Added because `bsp` is a direct caller today and `show` already means "one module in detail" |

`poke` goes (folded into `reload <module>`); its completion entry with it.

#### B6. The controller's own sources

Each source is a small class with `start`, `stop` and an availability check, writing state through the same
call `push` uses. Volume and player carry over from the zsh controller (the same streams, rules and texts);
the printer, scanner, VPN, Bluetooth and counter sources are new, built in Python from the start (B8).

#### B7. Today's direct polybar callers, and how each moves

| Caller | Moves to | When |
|---|---|---|
| `_coord-poke` | crew pushes its strip (`barctl push crew --json -`, segments per coordinator); `coord bar` and the `coord` hook go | With crew (brain record 0019's rename), see Part C |
| `_bsp-polybar-toggle` | `barctl hide` / `barctl unhide` | In barctl's cut-over PR (two lines in `_bsp`) |
| `_theme-reload-polybar`, `_theme-polybar-ping` | `barctl theme` (restart logic moves into barctl) | In barctl's cut-over PR; `_theme` keeps a one-line call until `theme` itself moves |
| `polybar-reload` | `barctl restart`; the script becomes a one-line `exec barctl restart "$@"`, kept so `.zlogin.d/99-polybar` and habits work, and removed when its callers say `barctl restart` | In barctl's cut-over PR |

#### B8. Modules still to build, and what the stopped printer and scanner work found

Built in Python from the start, as controller sources, each keeping its current module name
(`device-printer`, `device-scanner`, `device-bluetooth`, `menu-vpn`) so `bars/main` needn't change:

- **Printer:** `lpstat` on CUPS events or every 30 s. **Correction to record 0001's availability table:** on
  2026-11-04 `lpstat` called the Brother MFC-J5730DW "idle, enabled" while its device address
  (`socket://printer.andronics.io:9100`) did not answer (connections to 9100 and 631 timed out). CUPS's queue
  state is not the printer's. So the printer is unavailable when CUPS doesn't answer, the queue is missing or
  disabled, **or the device doesn't accept a connection on its print port within 2 s** (checked at most
  every 60 s).
- **Scanner:** the scanner is the same device, reached over the network through eSCL by `sane-airscan`,
  declared in `/etc/sane.d/airscan.conf` (`http://printer.andronics.io/eSCL/`). **Correction:** `scanimage
  -L` lists it even when it can't be reached, because it's declared by hand, so "SANE lists no device" never
  happens and can't be the test. On 2026-11-04 the capabilities query
  (`GET /eSCL/ScannerCapabilities`, port 80) timed out after 20 s and `scanimage` failed with "Error during
  device I/O". So the scanner module checks availability with a single `GET /eSCL/ScannerStatus` with a 2 s
  timeout, at most every 60 s and when its menu opens, never `scanimage`; offers scan actions only while that
  answers; and reports "scanning" from the status document's state. Until the network path to the printer's
  port 80 is fixed (a network question, not a bar one; Open question 10), the module will truthfully show
  unavailable. Evidence: `evidence/printer-scanner-findings/`.
- **VPN:** unavailable when the `nordvpn` daemon isn't running; idle when disconnected; active with the
  country as its label; the country list as dynamic menu rows; left click toggles.
- **Bluetooth:** BlueZ over D-Bus (`jeepney`), event-driven: unavailable with the adapter off or missing,
  idle powered with nothing connected, active with a device connected (its name as the label, its address
  as the target, so clicks act on it).
- **Counter** (record 0001's aggregate module, question 7): one GraphQL query through `gh` every 5 minutes
  with back-off (record 0001 question 8), plus the vault's tasks; Part C says how it reads the vault. It is a
  new module, so it needs a line in `bars/main`: Stephen has uncommitted edits to `bars/main` today, so its
  rollout waits for his say on where it goes and when.

### Part C: synergies

**crew (brain record 0019).** crew stops drawing: `coord bar` (and crew's equivalent) goes, and crew pushes
its strip to barctl as segments, one per coordinator, each with its tier (`unavailable` off, `idle` running,
`active` busy, `alert` waiting for input, the tiers `coord` already uses since PR 74), its glyph from the
registry, and its clicks from `modules.toml` (`left = crew toggle {segment}`, `right = crew quick
{segment}`, `middle = crew menu`, scroll to cycle). The `coord` polybar module becomes `crew`, `type =
custom/ipc`, `hook-0 = barctl render crew`; the "shown" underline becomes a segment flag. Pushes come from
Claude's hooks through `crew status`, so they're frequent: `push` is the fast path, skips run entries, and
writes nothing when nothing visible changed. crew pushes with a `--ttl` so a crashed hook can't leave a
coordinator shown as busy for ever. Renaming the module in `bars/main` from `coord` to `crew` collides with
Stephen's uncommitted edit there too.

**`meta desktop status` reads `barctl status --json`.** brain record 0019 recommends the desktop module be a
dotlib dispatcher, `meta-desktop`, in the dotfiles; under this record it is a console command in
desktop-tools instead (Open question 8). Its "polybar bars alive" check, and a line per unavailable or
alerting module, come from barctl's status, called in-process (the same package), not as a subprocess.

**Aggregate modules read `meta <centre> status --json`.** The counter's vault-tasks source asks `meta brain
status --json` (cached by `meta`, with `TOOL_STATS=skip`) instead of calling `vault-query` itself, so the
bar uses the front door like everyone else; its GitHub sources stay on one GraphQL query through `gh`. A
later "centre health" segment (a glyph per centre coloured by its `meta` state) could follow. brain record
0019's question 5 decided the bar does not use `meta` in v1; this is after v1, and the counter is built only
once the brain module (`meta brain`) exists (Open question 9).

**Logging (brain record 0017).** As A8: every barctl run is logged except `render` and `push`, which log only
their errors, rate-limited; bars started by barctl inherit `TOOL_STATS=skip`, so the polled `custom/script`
modules that remain don't flood the journal; `click` always counts. The controller (`run`) logs one run entry
per service life, and a warning each time a source restarts.

**Swarm alerts through `barctl alert`.** A coordinator waiting for input is `crew`'s segment in `alert`
tier; a short blink on that segment (`barctl alert crew --segment <name> --for 10s`) draws the eye when it
starts waiting. The brain coordinator's change of swarm mode to `incident` or `freeze`, or a new notice for
Stephen, can blink the crew module the same way (one command, `barctl alert crew --for 1m`), with the reason
in its `detail`. Nothing blinks for ever: every alert has an end.

## Alternatives considered

- **Keep the controller in zsh** (record 0001's choice). It works today, but Stephen's direction moves all
  tools to Python, and the next sources (D-Bus for Bluetooth and players, HTTP for the scanner, GraphQL for
  the counter, a control socket and timers for push and alerts) are where zsh is weakest.
- **One repo per tool.** Shared pieces (journal helper, theme roles, polybar IPC, detached runs) would be
  copied or published as yet another package; one install, one version pin and one CI are simpler.
- **Python tools inside the dotfiles** (a `python/` folder, run with `uv run`). No releases, no template
  updates, no CI (the dotfiles have none), and it mixes code with config, against Stephen's direction.
- **argparse instead of Typer.** Faster to start, stdlib, and readable by the brain's completion generator,
  but the template's wiki generator reads a Typer app and its updates would keep breaking it; the fast path
  (A1) gets argparse's start-up speed where it matters. Open question 3.
- **`push` through the controller only** (no file write by the pusher). One writer is tidier, but crew's
  strip would go blank whenever the controller restarts or is stopped; writing the file first keeps the bar
  correct without it.
- **Keep the state in `~/.local/state/barctl/`** as the zsh controller does. It survives logout, so a pushed
  state from yesterday could show as today's; the runtime folder can't.
- **A tooltip field shown on the bar.** polybar 3.7 has no tooltips; the `detail` field goes where it can be
  seen (`show`, `status`, `meta`, notifications).

## Consequences

- **Amends record 0001:** its question 1 ("one shared controller, in zsh as a dotlib module") becomes "one
  shared controller in Python, in andronics/desktop-tools"; its question 5's condition ("a separate config
  file only if the controller ends up outside zsh") is met, so quick actions move from `_barmenu`'s table to
  `modules.toml`; its question 6's table gains the two corrections in B8. Record 0001 itself is left as
  written: this repo's design-record README has no rule for marking an amendment on the old record, so the
  amendment is shown here and in the index.
- **Easier:** one place that knows the bar's state (`barctl status`, `show`, `watch`, `meta`); outside tools
  update the bar with one command and can't break its formatting; clicks act on what the bar shows; tests,
  CI and releases from the template; D-Bus and HTTP sources without text parsing.
- **Harder:** a second repo to keep, an install step (`uv tool`) in the dotfiles' postinstall, a version pin
  to bump, and two PRs per tool move. The bar now depends on a uv-managed Python being installed.
- **Wiki pages:** none here (the dotfiles have no wiki); `CLAUDE.md`'s "Bar controller" section and
  `REVIEW.md` change at the cut-over, not in this PR. desktop-tools' wiki is generated by the template.

### Migration and cut-over

1. **Before anything:** this record approved; the repo created and the desktop coordinator's actor note
   given it (Open questions 1 and 2).
2. **Build beside the zsh one:** desktop-tools gets barctl with volume and player at parity, `push`, `alert`,
   `click`, `menu`, `reload`, `restart`, `theme`, `hide`/`unhide`, `doctor`, `watch`, the journal helper and
   completions; tested in CI with fakes only. The zsh barctl stays live and untouched throughout.
3. **The cut-over** (one dotfiles PR and one install, a live change on the desktop, so it needs Stephen's go
   or the brain coordinator's on his behalf):
   1. `systemctl --user stop barctl.service`.
   2. Merge the dotfiles PR: remove `desktop/.local/bin/barctl`, `dotlib/_barctl`, `tests/barctl.zsh` and
      `_barctl_cmd`; add `desktop/.config/barctl/modules.toml` and the version pin; change the IPC modules'
      clicks to `barctl click <module> <button>`; `_bsp`, `_theme` and `polybar-reload` call barctl;
      `CLAUDE.md`'s section updated. `barctl.service` keeps its name and its `ExecStart`
      (`%h/.local/bin/barctl run`, which is where `uv tool` puts the command); its `DOTLIB` line goes.
   3. `./dotfiles reinstall desktop shell` (unlinks the zsh wrapper, installs the pinned desktop-tools and
      its completions).
   4. `systemctl --user start barctl.service`; `barctl restart`; `barctl doctor` exits 0; volume, player and
      clicks checked by hand.
4. **Rollback:** `systemctl --user stop barctl.service`; `uv tool uninstall desktop-tools`; revert the
   cut-over PR; `./dotfiles reinstall desktop shell` (re-links the zsh barctl); `systemctl --user start
   barctl.service`; `polybar-reload`. The zsh controller's state folder was never touched. Once other tools
   have moved, rollback of barctl alone is pinning the previous desktop-tools version and reverting only the
   barctl PR.
5. **Then** the new sources one at a time (printer, scanner, VPN, Bluetooth, the counter), each its own PR
   pair, the counter after Stephen's say on `bars/main`.

## Open questions

For the brain coordinator; 1 and 2 are Stephen's, as AGENTS.md reserves making anything public and changes
of an actor's scope to him. Each now has its **Decided** line.

1. **Create andronics/desktop-tools as a public repo?** Options: (a) public; (b) private. Recommendation:
   **(a)**: nothing in it is secret, the dotfiles are public, the template's secret scan guards every PR.
   Reserved to Stephen.

   **Decided (Stephen):** public.

2. **Give the repo to the desktop coordinator** (its actor note's `owns` and `merge_scope`, with Tagwarden's
   release PRs, Courier's template-update PRs and Dependabot's merged by it, as in its other repos).
   Options: (a) yes, as the brain's Tooling Conventions note already says; (b) another owner.
   Recommendation: **(a)**. A scope change: the steward proposes it, Stephen approves.

   **Decided (the brain coordinator, on Stephen's behalf):** as recommended.

3. **CLI library.** Options: (a) Typer as the template gives it, with the stdlib fast path for `render` and
   `push` (A1); (b) argparse everywhere (fastest, stdlib, the brain's generator), with the template's wiki
   generator's CLI block replaced in the project; (c) argparse, and ask the platform coordinator for an
   argparse option in template-python. Recommendation: **(a)**: it keeps template updates clean, and the
   fast path removes the start-up cost where it matters (measured: Typer adds 30 to 95 ms; the hot verbs
   don't pay it).

   **Decided (the brain coordinator, on Stephen's behalf):** as recommended.

4. **Dependencies.** Options: (a) as A5: allow `jeepney` when the first D-Bus source lands, not
   `dbus-next`, not `pulsectl` for now, not `pydantic`; (b) standard library only, D-Bus through
   `busctl`/`dbus-monitor` subprocesses; (c) allow all four. Recommendation: **(a)**.

   **Decided (the brain coordinator, on Stephen's behalf):** as recommended.

5. **Where `uv tool` puts commands.** Options: (a) `~/.local/bin`, beside the stow links (no PATH change;
   `uv` refuses to overwrite a linked wrapper, so a forgotten wrapper fails loudly); (b) a folder of its own,
   first on PATH (a rollback is a PATH change, but polybar, sxhkd and `barctl.service` each need it added).
   Recommendation: **(a)**.

   **Decided (the brain coordinator, on Stephen's behalf):** as recommended.

6. **The journal helper.** Options: (a) a copy of the brain's `tools/journal.py` in desktop-tools, with its
   test and the commit it came from; (b) a small shared package (for example `andronics/tool-journal`) that
   the brain and desktop-tools both depend on; (c) desktop-tools imports it from `/mnt/brain` at run time.
   Recommendation: **(a)** now (about 40 lines, standard library, the brain's tools must stay stdlib), and
   (b) only if a third Python repo needs it. (c) ties the bar to the vault being mounted.

   **Decided (the brain coordinator, on Stephen's behalf):** as recommended.

7. **Module state folder.** Options: (a) `$XDG_RUNTIME_DIR/barctl/` for states (gone at logout), settings in
   `$XDG_STATE_HOME/barctl/`; (b) everything in `$XDG_STATE_HOME/barctl/` as the zsh controller does, with a
   boot stamp to spot stale states. Recommendation: **(a)**: stale states can't exist, and the zsh
   controller's folder stays untouched for rollback.

   **Decided (the brain coordinator, on Stephen's behalf):** as recommended.

8. **Where `meta desktop` lives.** brain record 0019 recommends a dotlib dispatcher `meta-desktop` in the
   dotfiles. Options: (a) a console command `meta-desktop` in desktop-tools (Python, reads barctl's status
   in-process), registered by its path under `uv tool`'s folder; (b) as 0019 says, then moved later.
   Recommendation: **(a)**: it is a new tool, and new tools are Python; it avoids writing it twice.

   **Decided (the brain coordinator, on Stephen's behalf):** as recommended.

9. **The counter reading `meta brain status --json`.** brain record 0019's question 5 said the bar doesn't
   use `meta` in v1. Options: (a) the counter's vault-tasks source goes through `meta brain` once that module
   exists (after v1), and through `vault-query` until then; (b) `vault-query` always, as record 0001 said;
   (c) wait to build the counter until `meta brain` exists. Recommendation: **(a)**: the counter isn't
   first in line anyway, and the front door is where every other reader is heading.

   **Decided (the brain coordinator, on Stephen's behalf):** as recommended.

10. **The printer's network path.** On 2026-11-04 the printer (`printer.andronics.io`) answered on none of
    ports 80, 443, 631 and 9100, while CUPS called it idle. Options: (a) ask the network-tools or homelab
    coordinator (whichever owns the printer's network) whether it's a firewall rule or the device asleep,
    before the scanner module is built; (b) build the module now and let it show unavailable. Recommendation:
    **(a)**, sent by the brain coordinator; the module can still be built meanwhile, since its availability
    check is what tells the two apart.

    **Decided (the brain coordinator, on Stephen's behalf):** as recommended.

11. **`hide` / `unhide`.** The brief's verbs didn't include bar visibility, but `bsp` hides the bar today.
    Options: (a) two verbs, `hide` and `unhide` (the words `bsp` uses); (b) one, `visibility show|hide|toggle`.
    Recommendation: **(a)**.

    **Decided (the brain coordinator, on Stephen's behalf):** as recommended.

12. **`barmenu` moves with barctl.** Options: (a) in barctl's first wave, since every module menu is drawn
    by it and its rows move to `modules.toml`; (b) later, by `tool-stats` order, with barctl calling the zsh
    `barmenu` meanwhile. Recommendation: **(a)**: one cut-over for the bar instead of two.

    **Decided (the brain coordinator, on Stephen's behalf):** as recommended.
