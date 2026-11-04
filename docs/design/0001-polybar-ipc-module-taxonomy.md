# 0001: Polybar IPC module taxonomy

Status: Approved (by Stephen for question 7 and the colour tiers; by the brain coordinator, on Stephen's
behalf, for everything else; 2026-11-04)
Date: 2026-11-04
Authors: Stephen Cox (proposal); written up as a design record by the dotfiles coordinator

Stephen's proposal is kept as he wrote it, in [Decision](#decision) and [Questions, as
decided](#questions-as-decided). Everything marked **Coordinator's note** or **Coordinator's
recommendation** was added while writing it up: it describes the repo as it is today, or suggests an
answer. What was decided is in the **Decided** lines: under each question, and in the Decision sections
they change.

## Context

### What the bar is today

polybar 3.7.2, configured in `desktop/.config/polybar/`: `config.ini` includes every file in `modules/` and
`bars/`. Two bars inherit `bars/base` (which sets `enable-ipc = true`): `main` (bottom) and `audio` (top).
The modules fall into five groups:

| Kind of module | Modules | How it gets its text |
|---|---|---|
| IPC (`custom/ipc`) | `coord` only | `hook-0 = coord bar`, `initial = 1`. The `coord` command pokes it with `polybar-msg action coord hook 0` on every show, hide, launch and state change (`shell/.local/share/dotlib/_coord`) |
| Event stream (`custom/script` with `tail = true`) | `desk` | `desk watch` follows `bspc subscribe` and prints a line only when the strip changes (`dotlib/_desk`) |
| Polled script (`custom/script` with `interval`) | `audio-level`, `audio-device` (5 s), `bluetooth-status` (5 s), `player-metadata` (5 s), `player-play-pause` (1 s), `sys-time`, `sys-date`, `sys-idle` | Re-runs a command (`audio`, `bt`, `player`, `date`) every interval, whether anything changed or not |
| Static glyph (`custom/text`) | `device-bluetooth`, `device-printer`, `device-scanner`, `apps-*`, `run_gui`, `run_terminal`, `menu-layout`, `menu-screenshot`, `menu-settings`, `menu-vpn`, `menu-session`, `menu-power`, spacers | A fixed label. Clicking runs a command: `system-config-printer`, `simple-scan`, `bt menu`, an app, or `barmenu <menu>` |
| polybar menu (`custom/menu`) | `menu-theme`, `menu-lock` | polybar's own expanding menu |

The built-in `internal/bspwm` module (`modules/bspwm.ini`) is kept for rollback but not on a bar.

Volume is polled too (`audio-level`, every 5 s). The "pulsectl-based volume watcher" in question 1 is
PipeWire itself (`pipewire-pulse` and `wireplumber`), not a watcher of ours: nothing in this repo watches
volume today.

So the things this proposal is about have no state on the bar today: the printer, scanner and Bluetooth
device icons never change, the VPN button is a static glyph whose left-click opens a fixed rofi menu
(connect, disconnect, information, all `nordvpn` commands), the media player is polled, and there is no
GitHub activity module. Only `coord` works the way the proposal describes.

### How a click opens a menu today

`barmenu <menu>` (`dotlib/_barmenu`) opens a rofi menu just above the clicked button. Each menu is a row of
data in one table, `_BARMENU_ROWS`: menu name, glyph, label, command. So menus already show an icon column
and are already declarative. `barmenu` also works around a polybar 3.7 hazard: polybar's output pipes are
not closed on exec, so a long-lived process started from a click can inherit another module's pipe and
freeze the bar's next restart. `barmenu` drops inherited pipes and runs the chosen command detached
(`setsid -f`). `menu-theme` and `menu-lock` still use polybar's `custom/menu`.

### How theme colours reach the bar

From the approved theming design (dynamic theming, `ricing/DESIGN.md`, kept outside this repo), now in this
repo:

- `config.ini` includes the generated `~/.local/state/theme/current/polybar.ini`, which holds `[colors]`
  (semantic roles such as `bg`, `bg-alt`, `fg`, `fg-dim`, `dim`, `accent`, `busy`, `urgent`, `on-urgent`,
  `ok`, `warn`, plus the raw palette) and `[theme]` (fonts, bar height, line size). Modules use role names,
  never hues. `theme ensure` makes sure the file exists before polybar starts.
- A hook's output can't use `${colors.*}`: polybar expands those only in the ini, not in text a command
  prints. So `coord bar` reads the roles from the generated `theme.zsh` (through `theme-roles` in
  `dotlib/_theme`) on every redraw and writes them as `%{F#hex}` colour tags. `desk watch` reads them once at
  start and is restarted by the polybar restart that `theme reload polybar` does.
- The theming design guarantees contrast per role: `dim` (inactive icons, such as a coordinator that isn't
  running) stays at least 3:1 against `bg`, and `busy`, `urgent` and `accent` stay distinguishable from
  each other.
- `coord` already uses four visual states: `dim` when off, plain `fg` when running and idle, `busy` while
  busy, an `urgent` pill while waiting for input, plus an `accent` underline while shown.

### Why now

Stephen wants the device and status icons on the bar to show live state (is the printer on, is the VPN
connected, which player is playing), with right-click menus for each, and a GitHub activity readout. Doing
that one module at a time would give a different mechanism, hook layout and colour rule for each. This
record fixes a shared taxonomy first.

### Constraints

- polybar draws nothing on its own: no animation, no state, and a hook's text is fixed until it is poked again.
- Long-lived processes must not be children of polybar (the pipe hazard above).
- Colours come from theme roles, never hex in the repo, and must follow `theme apply`.
- This repo is public: no token or account detail may go into the bar's config.
- House style is zsh: shared logic in `dotlib` modules, with thin dispatcher scripts in `shell/.local/bin`
  (see `CLAUDE.md`); the theming design chose zsh over Python for its own helpers (its decision D11).

## Decision

Stephen's proposal, as written (lightly formatted; the wording is his).

### Mechanism

Polybar's `custom/ipc` module type holds no state of its own. Each module exposes numbered hooks (shell
commands); a hook's stdout becomes the module's displayed text when triggered externally via:

```sh
polybar-msg action "#<module-name>.hook.<N>"
```

All state (what's active, what icon to show, what color) lives in whatever process sends these messages, not
in Polybar. That process is the **controller**.

> **Coordinator's note.** Hooks are numbered from 0 in both the config (`hook-0`) and the action
> (`#coord.hook.0`), but `initial` counts from 1 (`initial = 1` runs `hook-0` at start). `coord` uses the
> equivalent older form, `polybar-msg action coord hook 0`.

### 1. Single-item IPC

One module, one concern. Represents a binary or small-state thing (a service, a toggle, a connection) as a
single icon.

- **Hooks:** one per discrete state. Minimum two: inactive (dim/grayed foreground) and active (accent-colored
  foreground, or a different glyph).
- **Controller:** either
  - dedicated: a per-module script/daemon that owns this module exclusively, or
  - shared: one daemon multiplexing across several single-item modules, each addressed by its own
    `#modname.hook.N` target. Preferred when event sources overlap (e.g. one dbus/systemd listener feeding
    several icons), since it collapses N independent poll loops into one process.
- **Alerts** ("needs attention"): not a third static state, a temporal one. The controller runs a timed loop
  alternating between two hooks (e.g. hook.1 ↔ hook.2) to blink, since Polybar itself won't animate a static
  hook.
- **State isn't always binary.** A print queue needs a count, not just on/off: the hook text becomes `🖨 3`
  rather than toggling between two fixed glyphs. The controller still owns this: it re-renders the hook's
  output string on every queue-depth change rather than firing a different hook index. Binary and
  count-based are the same mechanism (controller decides text, fires hook) with different payloads.

| Thing | States | Notes |
|---|---|---|
| VPN | disconnected / connected (+ per-country variants) | right-click menu, see Interaction layer below |
| Printer | idle / N jobs queued | numeric payload, not glyph-toggle |
| Scanner | idle / scanning | binary, but exposes quick-actions (see below) |
| App launcher | n/a (not really stateful) | click = launch; right-click = config/state actions |

> **Coordinator's note.** Today these are `menu-vpn`, `device-printer`, `device-scanner` and the `apps-*`
> modules, all static `custom/text` glyphs (see Context).

### 2. Multi-item IPC

One module, multiple competing sources. The module doesn't just toggle a state: it selects which source
currently owns it, then renders that source's icon/text. Mechanically this is a priority/selection problem
layered on the same hook-firing primitive.

- Example: media player module. Controller polls available MPRIS players (`playerctl -l`), picks whichever is
  Playing (or applies a priority order if several are), and fires the hook corresponding to that player's
  icon/track text.
- Controller is necessarily shared/stateful: it has to track source priority, not just on/off.

> **Coordinator's note.** Today the `player-*` modules are polled scripts over `dotlib/_player`, which maps
> players to icons from `instances.json` but has no priority rule: `playerctl` talks to whichever player it
> finds first.

### 3. Aggregate IPC

Distinct from both of the above: not toggling a state, not selecting one source, but combining several
counters into one glanceable readout. The GitHub-activity module is the motivating case: PRs merged, issues
opened, [unclear item: tasks/requests?] completed vs remaining, rendered together as a single compact string
(e.g. `PR:3 ISS:5 TASK:12/20`).

> **Decided (Stephen, question 7).** The third counter is selectable, from four sources: the vault's ☑️
> tasks (done vs open, through `vault-query`), GitHub Projects items, reviews requested of him, and issues
> closed vs open. One is picked in config, or cycled by scroll or click on the module.

- **Data source:** polled API (GitHub REST/GraphQL), not an event stream: no dbus signal fires when a PR
  merges. Controller polls on an interval and diffs against last-seen state to decide whether to re-render
  at all.
- **Rate limits** matter here in a way they don't for the other two types: GitHub's API has hard per-hour
  caps (higher with a PAT than anonymous). Poll interval is a real constraint, not a tuning nicety: it needs
  to be chosen against the limit, not just "every N seconds" by feel.
- **Payload** is a composite string, not a state index: this is hook-text-as-payload again (§1, §5) but with
  multiple sub-values concatenated by the controller into one render, rather than one glyph/color per state.
- **Click behavior** fits the same model as §4 below: left-click could open the GitHub activity page,
  right-click could menu into per-repo breakdowns if the aggregate is portfolio-wide.

### 4. Interaction layer

Separate from what a module displays is what clicking it does. Polybar modules support `click-left`,
`click-right`, `click-middle`, `scroll-up`, `scroll-down`, each bound to a shell command. This is independent
of the hook mechanism: hooks control render state, click bindings control user-triggered actions, and both
route through the same controller.

- **Left-click:** primary action (toggle the thing, or launch, for an app module).
- **Right-click:** pop a menu (rofi/dmenu-style) listing secondary actions specific to that module. This is
  per-module-type, not generic:
  - VPN: list of countries/server profiles to switch to.
  - Scanner: quick-actions (scan from flatbed, scan from auto-feeder, etc.). These are fixed,
    device-capability-derived choices, not dynamic state.
  - App launcher: show config, show state. "Show config" opens the app's config directory in a file manager
    (e.g. Nemo): the controller just shells out `nemo <path>`, no IPC hook involved.
- Menu items are themselves just shell commands the controller runs on selection. They don't need their own
  hooks unless the action should also change what the module displays afterward (e.g. switching VPN country
  should update the module's rendered text to the new country).

> **Coordinator's note.** Today left-click on `menu-vpn` opens the menu and there is no right-click; the
> proposal moves the menu to right-click and makes left-click the toggle. `coord` already follows the
> proposal's split (left-click toggles, right-click opens `coord menu`, scroll cycles).

### 5. Rendering preference

Icon-first by default (lucide/nerd-font glyphs), with a text/label fallback available per module, not
icon-only. This applies uniformly across single-item, multi-item, aggregate, and menu entries: a menu listing
VPN countries should be able to show a flag/icon next to the country name, not just text.

> **Coordinator's note.** The bar's icon font today is Symbols Nerd Font Mono (`font-icon` from the theme);
> no Lucide font is installed. Several current labels use legacy Nerd Font codepoints (U+F900 to U+FAFF)
> that newer Nerd Fonts dropped and that editors turn into CJK characters; `_barmenu` already writes its
> glyphs as byte escapes for that reason.

### 6. Color-state convention

Generalizes the earlier binary dim/accent scheme (§1) to three tiers, applied consistently across module
types:

| Tier | Meaning | Example |
|---|---|---|
| Dark (near-background) | unavailable: device off/not powered, service unreachable | printer powered off; scanner off |
| Gray (neutral/default) | idle: available, nothing happening | printer on, queue empty; VPN installed but disconnected |
| Accent (positive color) | active: currently doing something | printer has queued jobs; scanner scanning; VPN connected |

This is still hook-text-as-payload (§1): the controller picks the foreground color via `%{F#hex}` in the
string it writes to the hook, same mechanism as the glyph-toggle, just three color buckets instead of two.
"Unavailable" is a state the controller has to actually detect (device present/reachable): it's not just "no
jobs" (that's idle), so each module type needs its own availability check, not just a state poll.

> **Coordinator's note: tiers as theme roles (a suggestion, to confirm).** Under the theming design the hex
> must come from roles at render time, as `coord bar` does, not be written into the repo. The nearest fit:
>
> | Tier | Role | Why |
> |---|---|---|
> | Dark: unavailable | `dim` | The darkest role with a contrast guarantee (3:1 on `bg`); `border` and `surface` are nearer the background but have none, so an off icon could vanish |
> | Gray: idle | `fg-dim` | Secondary text, 4.5:1 on `bg`, visibly between `dim` and `fg` |
> | Accent: active | `accent` | As proposed. `ok` (green) is the alternative if accent should stay for focus only |
> | Alert (blink) | `urgent` | Matches `coord`'s waiting pill and urgent desktops |
>
> This differs from `coord`, where idle is plain `fg` and busy is `busy` (orange). Either `coord` moves to
> the three tiers or the record says why it differs.

> **Decided (Stephen).** These tiers, for every module, with colours read from the theme roles at render
> time: unavailable = `dim`, idle = `fg-dim`, active = `accent`, alert (blink) = `urgent`. `coord` changes
> to match (see Consequences).

## Alternatives considered

Stephen's proposal names no rejected alternatives. **Coordinator's notes** on the mechanisms the bar uses
today, and why each falls short for live state:

- **Polled scripts** (`custom/script` with `interval`, as `audio-level`, `bluetooth-status` and `player-*`):
  one loop per module, the display lags by up to the interval, and the command runs even when nothing
  changed. Kept for things that really are clocks (`sys-time`, `sys-date`).
- **An event stream per module** (`custom/script` with `tail = true`, as `desk`): event-driven, but one
  long-lived process per module, which outside processes can't poke, and which sits on polybar's pipes
  (the restart hazard in Context). Right for `desk`, which has one event source of its own.
- **polybar's built-in modules** (`internal/pulseaudio`, `internal/network`, `internal/bspwm`): no
  right-click menus of our own, no availability tier, no theme-role colours beyond the ini, and nothing
  for printers, scanners, VPN or GitHub.
- **polybar's own menus** (`custom/menu`, as `menu-theme` and `menu-lock`): expand inline on the bar, no
  icons column beyond the label, no dynamic rows. The bar is already moving these to `barmenu` (rofi).

## Consequences

**Coordinator's notes**, for review with the open questions:

- Easier: one pattern for every stateful icon; state shows at once instead of after a poll; one shared
  colour rule across modules; modules become interchangeable in `bars/main`.
- Harder: a controller is a long-lived process that must start with the session, outside polybar (a systemd
  user service or a `.zlogin.d` script, not a click or a `tail` module) because of the pipe hazard, and must
  survive polybar restarts (`initial =` redraws each module from the controller's current state when the
  bar comes back).
- Theme changes: a controller that reads roles on every redraw (as `coord bar` does) follows
  `theme apply` on its next poke; one that caches roles needs `theme reload polybar` to poke or restart it.
- Rate limits: the GitHub module shares the account's API budget with everything else that uses the same
  login (`gh`, scripts, agents), so its poll interval is budgeted, not free.
- Secrets: the GitHub module reads its token from the existing `gh` login or `pass` at run time; nothing goes
  into this public repo.
- Migration: one module at a time, in `bars/main`. Rollback is swapping the old module name back, as with
  `desk` and `bspwm`. `coord` already fits; the static `device-*`, `menu-vpn` and `player-*` modules are
  replaced as their controllers land.
- Glyphs: new labels should use current Nerd Font codepoints, not the legacy U+F900 to U+FAFF range.
- Wiki pages: none (this repo has no wiki). `REVIEW.md` and `CLAUDE.md` mention the bar's modules and may
  need a line when the first controller lands.

Following the decisions:

- `coord` moves to the colour tiers: idle becomes `fg-dim` instead of plain `fg`, and busy becomes `accent`
  instead of `busy`, with `urgent` kept for waiting on input. A follow-up change, not part of this record.
- Volume becomes event-driven: the controller follows `pactl subscribe` (served by `pipewire-pulse`) and
  replaces the polled `audio-level`.
- The build follows the coordinator rename (the dotfiles coordinator becomes the desktop coordinator) and
  comes as separate briefs, one change per controller or module, not as one change.

## Questions, as decided

Stephen's eight questions for the implementation pass, as he wrote them. Each has the options, the
**Coordinator's recommendation** made while the record was proposed, and the **Decided** answer. Stephen
decided question 7 and the colour tiers; the brain coordinator decided the rest on his behalf.

1. **Shared-controller process:** single Python daemon (natural fit alongside existing pulsectl-based volume
   watcher) vs one daemon per concern?
   - Options: one shared Python daemon; one daemon per concern; one shared controller in zsh as a `dotlib`
     module, like `_coord` and `_desk`.
   - Coordinator's recommendation: one shared controller, but in zsh as a `dotlib` module with a thin
     dispatcher, run as a systemd user service, unless a source needs a library zsh can't reach. No
     pulsectl volume watcher exists in this repo today (`audio-level` polls every 5 s), and the house style
     and the theming design's helpers are zsh. The event sources can be read from command-line tools
     (`pactl subscribe`, `dbus-monitor`, `lpstat`, `playerctl --follow`). Revisit if one of them can't.
   - **Decided:** one shared controller, in zsh as a `dotlib` module with a thin dispatcher, run as a
     systemd user service. The "pulsectl volume watcher" was PipeWire itself (`pipewire-pulse` and
     `wireplumber`), not a watcher of ours (see Context); volume becomes event-driven through `pactl
     subscribe` inside the controller.

2. **Hook-count convention:** fix a minimum hook set per type (e.g. single-item always 0=inactive, 1=active,
   2=alert) so modules are interchangeable in config?
   - Options: a fixed hook set per type (one hook per state); a single render hook per module (`hook-0`),
     whose command prints whatever the controller's current state is.
   - Coordinator's recommendation: a single `hook-0` render hook for every type, as `coord` does today. The
     proposal already makes the text the payload (counts, colours, composite strings), so per-state hooks add
     config without adding anything a render hook can't do; a blink is the controller flipping its state and
     poking `hook-0` twice. Every module is then interchangeable by construction.
   - **Decided:** one render hook (`hook-0`) per module, as `coord` does.

3. **Multi-item priority rule** when multiple sources are simultaneously active: last-changed wins, explicit
   priority list, or user-selectable?
   - Options: last-changed wins; explicit priority list; user-selectable; or a combination.
   - Coordinator's recommendation: Playing beats Paused beats Stopped; among several playing, the one that
     changed most recently wins; scrolling on the module pins another source until it stops. A fixed
     priority list goes in the same `instances.json` the player module already reads, only as a tie-break.
   - **Decided:** Playing beats Paused beats Stopped; then the most recently changed player wins. (Pinning
     by scroll and an `instances.json` tie-break were not part of the decision.)

4. **Right-click menu renderer:** rofi, dmenu, or a custom picker; needs icon support if rendering preference
   (§4) [the rendering preference is §5] applies to menus too.
   - Options: rofi; dmenu; a custom picker.
   - Coordinator's recommendation: rofi through the existing `barmenu`. It already opens above the clicked
     button, shows a glyph column (and can show image icons, such as flags), is themed from the theme
     roles, and handles the polybar pipe hazard. dmenu has no icons; a custom picker would redo all of that.
   - **Decided:** right-click menus through `barmenu` (rofi).

5. **Where module-specific quick-action lists** (scanner, VPN) live: hardcoded per controller, or a
   declarative config the controller reads so adding a new action doesn't mean editing Python?
   - Options: hardcoded per controller; a declarative config file the controller reads.
   - Coordinator's recommendation: declarative, by extending `barmenu`'s existing rows table (menu, glyph,
     label, command), so fixed actions such as the scanner's are one line each. Dynamic rows (VPN countries)
     are generated by the controller at menu time, using the same row shape. A separate config file only
     if the controller ends up outside zsh.
   - **Decided:** quick actions are rows in `barmenu`'s table; dynamic rows (such as VPN countries) are
     generated by the controller.

6. **Availability detection per module type:** what counts as "unreachable" for each (printer: CUPS queries
   fail vs returns no printer; scanner: SANE device list empty; VPN: interface absent) needs enumerating per
   integration, not a generic check.
   - Options: enumerate per integration in this record; or per integration in each module's implementation
     change.
   - Coordinator's recommendation: agree the table here before code, starting from: printer unavailable
     when CUPS doesn't answer or the printer is missing or disabled (`lpstat`); scanner unavailable when
     SANE lists no device (`scanimage -L` takes seconds, so check it rarely or on USB plug events, not every
     poll); VPN unavailable when the `nordvpn` daemon isn't running (disconnected is idle); Bluetooth
     unavailable when the adapter is off or missing.
   - **Decided:** a per-device availability table first, before code:

     | Device | Unavailable when | Checked |
     |---|---|---|
     | Printer | CUPS doesn't answer, or the printer is missing or disabled (`lpstat`) | each poll or event |
     | Scanner | SANE lists no device (`scanimage -L`) | rarely, or on USB plug events: the check takes seconds |
     | VPN | the `nordvpn` daemon isn't running (disconnected is idle) | each poll or event |
     | Bluetooth | the adapter is off or missing | each poll or event |

7. **Aggregate module:** the "tasks completed vs remaining" counter wasn't fully clear from the voice note;
   needs confirming what that third figure actually tracks (project board tasks? review requests? something
   else) before specifying the controller's GitHub API calls.
   - Options: GitHub project board items (done vs total); review requests waiting on you; issues closed vs
     open in a milestone; something else.
   - Coordinator's recommendation: none. This is Stephen's to say.
   - **Decided (Stephen):** selectable, from four sources: the vault's ☑️ tasks (done vs open, through
     `vault-query`), GitHub Projects items, reviews requested of him, and issues closed vs open. One is
     picked in config, or cycled by scroll or click on the module.

8. **Aggregate module poll interval vs GitHub rate limit budget:** needs a concrete number once the API calls
   (REST vs GraphQL, which scopes) are picked, since GraphQL's single-query-multiple-field shape may let one
   poll cover PRs+issues+tasks in one rate-limit unit instead of three.
   - Options: REST, one call per counter; GraphQL, one query for all counters; and an interval.
   - Coordinator's recommendation: one GraphQL query per poll through the existing `gh` login, every 5
     minutes, with the controller backing off when the remaining budget reported by the API runs low. An
     authenticated account gets 5,000 GraphQL points an hour and a small query costs about one point, so 12
     polls an hour is well under 1% of the budget. The budget is shared with every other use of the same
     login, which is why the interval should stay in minutes, not seconds. Search-based counts use the
     separate search limit (30 a minute), which a 5-minute poll also stays well inside.
   - **Decided:** as recommended: one GraphQL query every 5 minutes through `gh`, backing off when the
     remaining budget runs low. (The vault's tasks are read locally through `vault-query`, not from GitHub.)

## Open questions

None.
