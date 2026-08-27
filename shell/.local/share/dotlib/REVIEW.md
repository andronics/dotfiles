# dotlib review

Independent review of the dotlib codebase (`shell/.local/share/dotlib/`), done ahead of a possible rewrite/refactor decision. Scope: all 55 modules (~57,500 lines) plus how they're actually invoked from `shell/.local/bin/`, `desktop/.local/bin/`, and systemd units. ARCHITECTURE docs were deliberately not consulted — conclusions below come from reading the code, `git log`, and grepping real call sites.

Method: I read `README.md`, `_common`, `_dispatcher`, and `_remote` myself; the other 51 modules were read in full (not sampled) across four parallel passes, each required to cite `file:line` for every claim. Every "zero consumers" claim was verified by grepping the whole repo, not just dotlib.

## Headline finding: half the library has never run for real

dotlib's own `_tour` module says it outright, in its own header comment:

> "Most of dotlib's modules are written but never exercised by a real wrapper... This module runs real demos through them."

That's not editorializing — it's accurate, and it's the single most important fact for a rewrite decision. Splitting the 55 modules (57,524 code lines) by who actually loads them:

| Tier | Modules | Lines | % | What it means |
|---|---|---|---|---|
| **Loaded by a real wrapper** | 31 | 29,348 | 51% | Transitively `source`d when you run `audio`, `player`, `bt`, `remote`, `bsp`, `lockscreen`, `screenshot`, or `pie` |
| **Tour-demo-only** | 19 (incl. `_tour`) | 22,059 | 38% | Only ever sourced by the self-demo `tour` command; no task wrapper claims them |
| **Zero consumers anywhere** | 5 | 6,117 | 11% | Not even `_tour` sources them |

So **49% of the codebase (28,176 lines) has no production caller at all.** And within the "loaded" 51%, several modules are loaded-but-dormant: sourced for side effects on every shell invocation but with their actual public API never called by the real code path (see below). The genuinely *exercised* fraction of the library is smaller than 51%.

Orphaned modules (never sourced by anything, not even `_tour`): `_ai_core` (2089 lines), `_ai_claude` (962), `_git` (1218), `_template` (1124), `_dryrun` (724).

Tour-only modules (real, substantial code, zero task wrappers): `_vpn` (2905 — the single largest file in the library, 100% NordVPN-specific), `_docker` (2042), `_acpi` (1766), `_wifi` (1597), `_async` (1437), `_crypto` (1380), `_args` (1210), `_rules` (997), `_schema` (941), `_validation` (938), `_actions` (930), `_server` (835), `_http` (821), `_test` (818), `_plugins` (710), `_ui` (721), `_patterns` (595), `_network` (398).

Even the "loaded" tier overstates real usage. Confirmed loaded-but-dormant (sourced on every real invocation, public API never called by the real caller):
- `_config` — sourced by `audio`/`player`/`bsp`; its `config-get`/`config-set`/`config-load` are never called by any of them.
- `_process` — sourced transitively by `_systemd`/`_player`/`_xidlehook`/`_bluetooth`/`_server`; its `process-*` API has zero external callers.
- `_string` — sourced by `_player`; its case-conversion/hash/codec functions have zero external callers.
- `_rclone` — sourced by `_remote`; only 6 of ~80 public functions (`rclone-check-available`, `-unmount`, `-is-mounted`, `-set-config`, `-set-filter-file`, `-move`) are actually called. The other ~74 (serve-http/webdav/ftp/sftp/restic, RC API, bisync, dedupe, remote CRUD, `rclone-mount` itself) are dead weight riding along inside a "used" module.
- `_rofi` — sourced by `screenshot`; ~3 of ~50 public functions are exercised.

**A structural note on why `_tour`'s QA never caught the worst bugs**: `_tour`'s own house rules explicitly forbid it from calling mutating functions — "every mutating function in those modules (connect, start, kill, forget, prune, trigger, login, ...) is deliberately never called." That's a reasonable safety choice for a demo you run unattended, but it means the one testing mechanism this codebase has is structurally blind to exactly the code paths most likely to be dangerous (see the `_wifi` and `_crypto` findings below — both are in modules `_tour` "covers," and both bugs are in the mutating functions `_tour` deliberately skips).

## What's genuinely good

Worth naming plainly, because the codebase is not uniformly bad — the quality is bimodal, and knowing where the good half is matters for a rewrite-vs-refactor call:

- **`_dispatcher`** — the git-style subcommand router is well-designed and has a documented, correct fix for a real `set -e` interaction bug (dispatcher:529-536: capturing a subcommand's exit code without tripping errexit on failure).
- **`_singleton`** — three well-documented, hard-won zsh quirks (a `trap` inside a function fires on function return, not process exit, in zsh; bare `exec N>file` only works for single-digit fds, forcing the `exec {fd}>file` dynamic form; why a trailing `2>/dev/null` on that exec would permanently blackhole stderr). This reads as real incidents, not generated prose.
- **`_bspwm`** — the daemon-loop code has three separate comments reasoning correctly about `set -e` interaction and a genuinely obscure zsh footgun (`FUNCTION_ARGZERO` makes `$0` resolve to the function's own name inside a function, silently defeating auto-detected singleton-lock naming). This is evidence the author, not just one "hardening session," can write tight code.
- **`_xidlehook` / `_bluetooth`** — comments document specific debugging against real hardware (a `Connected: yes` grep bug, a Pairable side-effect discovered by comparing CLI forms). `_bluetooth` also correctly avoids `eval` in favor of `${(z)cmd}` array-splitting — contrast with `_wifi` below.
- **`_remote` family** — the best-commented code in the library: explains *why* dry-run is per-subcommand instead of the dispatcher's global flag, why mount is deliberately not delegated to `_rclone-mount`, why a wedged FUSE mount needs a bounded `stat` check in addition to `rclone-is-mounted`. `remote-sync` (the one function that deletes local files after transfer) has real layered mitigations: a singleton lock, a mount-liveness check, and an explicit preview mode.
- **`_log`** — one comment (`_log:256-265`) documents a real production incident: log output on stdout at certain levels was leaking into command-substitution captures and corrupting return values. Load-bearing knowledge.
- **`_patterns` / `_rules` / `_cache` / `_singleton` / `_config` / `_xdg` self-tests** — genuinely assertion-based (checking real counts/state), not decorative pass/fail printouts.

## Confirmed bugs

These aren't style opinions — each was verified by reading the code path (and in one case, by actually running it).

### Empirically verified: `_lifecycle` fails to source cleanly, every time

`_lifecycle` (2580 lines, the largest module, loaded by nearly everything) ends with 16 `export -f <function>` statements. **`export -f` is not valid zsh syntax.** I ran it directly:

```
$ zsh -c 'foo(){ :; }; export -f foo'
zsh:export:1: invalid option(s)
```

Sourcing `_lifecycle` standalone reproduces exactly 16 such errors, one per line. Every consumer sources it as `source "${DOTLIB}/_lifecycle" 2>/dev/null || true`, which silently swallows all 16 errors on every shell that loads it. This has apparently never been noticed despite firing constantly.

### Confirmed: a cross-module function name that was never defined

`_lifecycle` defines `lifecycle-cleanup-add`. Five other modules call a *different* name, `lifecycle-add-cleanup`, which does not exist anywhere in the library: `_process:72`, `_http:71,158`, `_crypto:86`, `_dispatcher:75`, `_git:72`. Two more call `lifecycle-register-cleanup` (also never defined): `_notify:160`, `_ai_core:310`.

These calls are gated behind `common-command-exists "lifecycle-add-cleanup"`, which always evaluates false, so the dependent cleanup-registration code (e.g. temp key file cleanup in `_crypto:791`, temp HTTP file cleanup in `_http:158`) is silently dead. In `_notify`'s case there's a *second*, independent bug masking the first: `_notify:159` gates on `${_LIFECYCLE_LOADED}` (leading underscore), but `_lifecycle`'s actual guard variable is `LIFECYCLE_LOADED` (no underscore, `_lifecycle:40`) — so that guard is also always false. Two bugs cancel out and mask each other, which is exactly the kind of thing that survives indefinitely because it never produces a visible symptom.

### Security-relevant, by severity

1. **`_wifi:790,836,1142` — command injection.** `wifi-connect`, `wifi-connect-hidden`, and `wifi-ap-start` build an `iwctl` command as a string and `eval` it, interpolating `$ssid`/`$passphrase` directly:
   ```
   local cmd="iwctl station \"$device\" connect \"$ssid\""
   eval "$cmd" 2>/dev/null
   ```
   An SSID containing `` ` ``, `$(...)`, `"`, or `;` breaks out of the quoting into arbitrary shell execution — and SSIDs are adversary-chosen input (any nearby AP operator can name their network anything). `_bluetooth`, in the same library, solves the identical problem safely with `${(z)cmd}` array-splitting instead of `eval` — the safer pattern was already known elsewhere in the codebase.

2. **`_crypto` — several real weaknesses in a module that exists specifically to do crypto correctly.**
   - `crypto-hash-password` (`:847-884`) does one round of raw SHA256, while the module elsewhere correctly implements PBKDF2 with a configurable iteration count (`CRYPTO_PBKDF2_ITERATIONS=100000`) — just not in the one function that most needs it.
   - `crypto-encrypt`/`-decrypt` pass the password via OpenSSL's `-pass pass:"$password"` (`:557` etc.) — the least-safe of OpenSSL's three password-input methods; visible to any local user via `ps`/`/proc/<pid>/cmdline`. They also silently accept `$CRYPTO_PASSWORD` from the environment (`:539,632`).
   - `crypto-verify-hash`/`-hmac`/`-password` (`:374,466,911`) and `_http`'s `webhook-validate-signature` (`:645`) all use `==` for comparison — a timing side-channel on every signature/password check in the library.
   - `crypto-random-number` (`:240`) does `random_int % range` — modulo bias, wrong if this is ever used for anything requiring uniform randomness (tokens, OTPs).

3. **`_docker:959-963,1273,1416,1484` — JSON injection.** Container `Cmd` arrays, volume names, and network config are string-concatenated into JSON sent to the Docker socket with no escaping. Docker socket access is root-equivalent.

4. **`_vpn:2901` — a surprising side effect from just sourcing the file.** Loading `_vpn` registers `vpn-disconnect` as a shell-exit `_lifecycle` cleanup hook. Since `_vpn` is sourced by `_tour`, running the demo command can tear down an active NordVPN connection on shell exit — a mutating, security-relevant action from what should be inert module loading.

5. **`_bluetooth:1722,1757` — the only unconditional `sudo` in the library**, with no check for passwordless sudo or an interactive terminal; will hang or prompt unexpectedly if triggered from a non-interactive context.

### Correctness bugs (non-security)

- **Pipeline exit-code bugs**: `_acpi:608` and `_http:196` both capture `$?` after a pipe (`nc | while read...`, `curl ... | tail -1`), which captures the *last* command in the pipe's exit status, not the one being checked — the "did this fail" check never actually reflects the intended command's failure.
- **`_dispatcher` file-mode dead code**: `dispatcher-execute-command`'s file-routing branch (`:573`) does `exec "$cmd_path" "$@"`. On success, `exec` replaces the process — the after-hooks and completion-event lines below it (`:577-582`) never run. They only fire if `exec` itself fails to launch.
- **`_dispatcher` duplicate flag parsing**: global-flag handling exists twice — once inline in `dispatcher-execute` (`:599-608`) and once in the separate, differently-invoked `dispatcher-parse-global-flags` (`:431-472`).
- **`_ai_claude:185-249` — `claude-exec` would never work if called.** It invokes the Claude Code CLI without `--print`/`-p`, which the CLI requires for non-interactive output — every call would launch the interactive TUI instead, hang until the wrapping `timeout` fires, and return a timeout error. Every function built on `claude-exec` (session start/continue, JSON exec) inherits this. Direct evidence the module has never been run end-to-end.
- **`_ai_core`/`_ai_claude` — undefined error constants.** `$AI_ERR_FILE_NOT_FOUND`, `$AI_ERR_VALIDATION_FAILED`, `$AI_ERR_CACHE_OPERATION_FAILED` are referenced (9+ call sites) but never declared. `return $UNDEFINED_VAR` in zsh returns the *previous* command's exit status, so every error path in this module reports the wrong code.
- **`_remote_config:27-30` — no error handling on config loads.** `credentials.json`/`filters.json`/`roots.json`/`units.json` are read via unchecked `$(cat ...)` at source time. A missing or unreadable file (plausible — `credentials.json` is explicitly git-ignored) makes every downstream query silently return `null`/empty rather than erroring, in a module upstream of `remote-sync`'s file-deletion path.
- **`_config:665,731` vs `_cache:189,219`** — the two modules disagree on whether an explicitly-set empty string counts as "present." `_config` treats empty as absent; `_cache` correctly distinguishes unset-vs-empty via `${...+exists}`. Same problem, two different (and inconsistent) answers, in sibling modules.
- **`_rclone:263-269`** — verbosity flags are built by string concatenation (`v_flag+="-v"` looped N times), producing `"-v-v"` as one malformed argument instead of `-vv` or `-v -v`, for any verbosity setting above 1.
- **`_player`** — 20+ call sites (`:626,660,694,...,1596`) build playerctl commands via string interpolation and `eval` rather than arrays, the same injection *pattern* as `_wifi` (player names aren't attacker-controlled today, but it's the same fragile idiom the rest of the codebase — `_bspwm`, `_remote`, `_bluetooth` — deliberately avoids).
- **`_jq`** — most convenience wrappers (`jq-get`, `jq-delete`, `jq-rename-key`, `jq-split`/`-join`/`-replace`, `jq-select-keys`) interpolate keys/separators directly into the filter string instead of using `--arg` (which `jq-query` itself supports correctly). A key containing `"` breaks or alters the filter.

## Architectural and consistency issues

**Three incompatible wrapper conventions now coexist.** The documented contract (`dispatcher-init`/`dispatcher-execute`, ≤30 lines, README-specified) is followed by 8 of the real wrappers. But the newest, currently-uncommitted desktop scripts (`bsp-flag`, `bsp-ventilate`, `bsp-floating-borders` — all `??` in `git status`) use a completely different, older-looking convention: `source $(which _log)`, `source $(which _onexit)`, `source $(which _singleton)`. **`_func` and `_onexit` don't exist anywhere in the repo** — these scripts are currently broken if run (consistent with them being WIP: several handler functions call `_func_unimplemented` stubs). Separately, a third category of real, working scripts (`wifi-monitor`, `terminal`, `nemo-rename`, `x11-info`/`-monitor`/`-events`, `sxhkd-bindings`, `polybar-reload`) uses no shared library convention at all — they're standalone. Notably, `wifi-monitor` (111 lines, real, working) reimplements wifi-status logic from scratch rather than using the 1597-line `_wifi` module that already exists for exactly that purpose. Taken together: even the user's own newest work isn't converging on the documented contract.

**`_common` is a kitchen-sink.** One file mixes XDG paths, ANSI color constants, a flat-file command-existence cache (grep/sed rewritten on every miss — not concurrency-safe), string "sanitization" via character blocklist (an inherently incomplete approach to injection defense), retry/timeout wrappers, root/privilege checks, and macOS detection — on a single-machine, Linux-only, Arch-based personal setup. `common-path-sanitize`'s docstring says it "prevent[s] traversal attacks" but it only *normalizes* `..`/symlinks; it enforces no boundary, so the name overstates what it does.

**Duplicate-load boilerplate is a repeated, mechanical bug, not a one-off.** `_string` and `_notify` each source `_common`/`_log` twice in sequence, with two *different, inconsistent* sets of fallback stub functions defined at each site (the second is dead due to the source guard, but represents drift between the two copies). `_validation`, `_rules`, and `_ui` have the same doubled "Source Guard" → "Load Dependencies" → repeat pattern. This reads as templated generation that was never deduplicated, not code written twice on purpose.

**The self-test convention is honored inconsistently, including in production modules.** `_lifecycle`, `_singleton`, `_cache`, `_config`, `_xdg`, `_patterns`, `_rules`, `_git` have real, assertion-based self-tests. `_log`, `_player`, and `_remote` — all genuinely production, all in the direct path of real user actions — have **no self-test at all**. `_ai_core`/`_ai_claude` have no self-test, help, *or* version function. `_plugins` has none either.

**Fictional/generic content suggests templated generation over need-driven writing.** `_actions`' help text documents a `docker.volume` backup handler example — this repo has no docker wrapper. `_template`'s install instructions curl a pinned old gomplate release rather than referencing the `pacman -S gomplate` this Arch system would actually use (despite CLAUDE.md documenting gomplate as already wired in). Version banners ("Part of the dotfiles library v2.0", "v3.1 NEW", "v3.2 NEW") appear throughout for a single-developer, unreleased, no-changelog codebase.

**Duplication across modules that should share code but don't:**
- `crypto-url-encode`/`-decode` (`_crypto:1002-1060`) is byte-for-byte identical to `_http`'s `http-url-encode`/`-decode` (`_http:432-490`).
- `_docker` hand-rolls its own curl calls rather than using `_http`, despite listing `_http` as an optional dependency.
- `_schema`, `_actions`, and `_template` each maintain their own independent "current execution context" associative array (`_SCHEMA_CURRENT`, `_ACTIONS_CONTEXT`, `_TEMPLATE_CONTEXT`) for what is conceptually one pipeline's state.
- `_validation` (generic type/constraint checking) and `_schema` (ad hoc jq-based structural checks) solve the same "is this data shaped right" problem with zero code sharing between them.
- `_rules`, `_actions`, and `_dryrun` each independently reimplement "if dry-run, log and skip, else execute," despite `_dryrun` existing as exactly the shared abstraction for this and being an optional dependency of `_rules`.
- `_network`, `_server`, and `_docker` each have their own hand-rolled "is this port/socket open" check.
- `_vpn` repeats the same 25-line cache-check/fetch/cache-store block five times (`vpn-api-countries/-technologies/-groups/-recommendations/-servers-filtered`) instead of factoring one helper — in the same file, not even across files.

**`eval`-on-interpolated-input is a recurring pattern**, not isolated to `_wifi`/`_player`: `_actions:628-629` (`eval`s a per-action cleanup function built from a schema-supplied `$action_id`), `_dryrun:497,517,545` (`eval`s caller- or file-supplied condition/command strings — the most eval-heavy file found), `_plugins:468` (in a function its own docstring marks `DEPRECATED`, but which is still live code), `_events:199-211` and `_lifecycle:611-618` (both `eval` string-interpolated function bodies for `events-once`/wrapper generation).

## Per-file quick reference

Tier legend: **P** = loaded by a real wrapper (production), **T** = tour-demo-only, **Z** = zero consumers anywhere. Self-test: ✓ real (assertion-based), ~ decorative/partial, ✗ absent.

| Module | Lines | Tier | Self-test | Notable finding |
|---|--:|:-:|:-:|---|
| `_vpn` | 2905 | T | ✓ | Largest file in lib; 100% NordVPN-specific; sourcing registers a disconnect exit-hook |
| `_lifecycle` | 2580 | P | ✓ | **16 invalid `export -f` errors on every load**, silently swallowed |
| `_bluetooth` | 2042 | P | ✓ | Real hardware-debugged; only unconditional `sudo` in the lib |
| `_docker` | 2042 | T | ✓ | JSON injection into Docker socket calls |
| `_ai_core` | 2089 | Z | ✗ | Undefined error constants; O(n²) hand-rolled template parser |
| `_rclone` | 2338 | P (6/~80 fns used) | ✓ | Malformed `-v` flag concatenation |
| `_acpi` | 1766 | T | ✓ | Pipeline exit-code bug (`nc \| while read`) |
| `_bspwm` | 1677 | P | ✓ | Best `set -e`/zsh-quirk reasoning in the library |
| `_wifi` | 1597 | T | ✓ | **`eval` command injection** via SSID/passphrase |
| `_player` | 1918 | P | ✗ | 20+ `eval`-built commands; no self-test despite being production |
| `_crypto` | 1380 | T | ✓ | Weak password hashing, CLI-visible passwords, timing side-channels |
| `_jq` | 1349 | P | ✓ | Convenience wrappers skip safe `--arg` interpolation |
| `_audio` | 1542 | P | ✓ | — |
| `_rofi` | 1275 | P (~3/50 fns used) | ✓ | — |
| `_git` | 1218 | Z | ✓ | Unescaped heredoc JSON build; would duplicate the user's manual git workflow |
| `_template` | 1124 | Z | — | Stale-looking install path detection from a different project layout |
| `_cava` | 1171 | P | ✓ | FIFO reader can block indefinitely if `cava` fails to attach |
| `_args` | 1210 | T | ✗ | Completion generators/subcommand API unused even by `_tour` |
| `_events` | 1093 | P | ✓ | `eval`-based dynamic wrapper generation |
| `_config` | 1054 | P (loaded, API dormant) | ✓ | Empty-string-vs-unset inconsistent with `_cache` |
| `_singleton` | 1060 | P | ✓ | Three well-documented hard-won zsh quirks |
| `_common` | 928 | P (foundation) | ✓ | Kitchen-sink scope; incomplete "security" sanitizer |
| `_string` | 931 | P (loaded, API dormant) | ✓ | Sourced by `_player` twice with drifted fallback stubs |
| `_validation` | 938 | T | ✗ | — |
| `_schema` | 941 | T | ✗ | Unescaped path interpolation into a Python `-c` string |
| `_rules` | 997 | T | ✓ | Best self-test of the speculative tier |
| `_dispatcher` | 997 | P (infra) | ✓ | Duplicate flag-parsing logic; dead code after `exec` on success |
| `_ai_claude` | 962 | Z | ✗ | `claude-exec` missing required `--print` flag — would hang, not work |
| `_process` | 958 | P (loaded, API dormant) | ✓ | Wrong availability-check pattern (`common-command-exists` vs `typeset -f`) |
| `_http` | 821 | T | ✓ | Timing-unsafe webhook signature comparison; pipeline exit-code bug |
| `_server` | 835 | T | ✓ | PID-tracking fragility on background server launch |
| `_systemd` | 800 | P | ✓ | Solid, unsurprising |
| `_log` | 774 | P (foundation) | ✗ | Real stdout/stderr corruption bug-fix documented; no self-test |
| `_xidlehook` | 785 | P | ✓ | Real-hardware-debugged, cleanest file in the lib |
| `_dryrun` | 724 | Z | ✓ | Most `eval`-heavy file; auto-runs its own self-test |
| `_ui` | 721 | T | ✓ | Duplicate source-guard boilerplate |
| `_plugins` | 710 | T | ✗ | Sources arbitrary files from hardcoded, non-repo-scoped paths |
| `_notify` | 696 | P (thin: 1 real consumer) | ✓ | Duplicated fallback stubs; masks the `lifecycle-add-cleanup` bug |
| `_xdg` | 657 | P | ✓ | Thorough self-test |
| `_cache` | 620 | P | ✓ | Correct empty-vs-unset handling; base64 line-wrap fix documented |
| `_patterns` | 595 | T | ✓ | Declared input validator never actually wired into the matching path |
| `_remote` | 583 | P | ✗ | Best comments in the library; no self-test |
| `_bt` | 506 | P (thin wrapper) | — | Delegates cleanly to `_bluetooth` |
| `_network` | 398 | T | ✓ | Duplicates connectivity checks `wifi-monitor` needed but didn't use |
| `_format` | 311 | T (`_tour` only) | ~ | — |
| `_lockscreen` | 184 | P | — | — |
| `_remote_config` | 141 | P | — | Unchecked `cat` on 4 config files, upstream of file-deletion |
| `_screenshot` | 158 | P | — | — |
| `_remote_filters` | 97 | P | — | Clean; deliberate per-file mediainfo caching |
| `_kando` | 66 | P | — | — |
| `_remote_patterns` | 57 | P | — | Clean; documented `set -e`-safe grep pattern |

## Assessment

The codebase is bimodal, and the split tracks usage almost exactly: **the ~51% that real wrappers load is where the good engineering lives** (`_bspwm`, `_singleton`, `_remote` family, `_log`, `_xidlehook`, `_bluetooth`) — comments that explain real debugging, correct handling of genuine zsh footguns, layered defenses around the one genuinely destructive operation (`remote-sync`). **The ~49% with no production caller is where the problems concentrate** — not because unused code is inherently worse, but because it was written once against a hypothesis of future need and never pressure-tested by a real call site, so bugs that a single real invocation would surface (undefined error constants, a CLI flag that doesn't exist, an `eval` on adversary-influenceable input) persisted.

That split argues against a uniform full rewrite and for something more targeted: the production-loaded modules are, on the whole, worth keeping and incrementally hardening (they already carry hard-won knowledge that a rewrite would have to relearn); the tour-only and zero-consumer modules (60% of the line count) are candidates for deletion or a deliberate "promote or delete" pass rather than line-by-line refactoring — there's no code to preserve the *value* of if nothing calls it, only the *idea*, and the idea can be re-scoped in a lot fewer lines if and when a real use case shows up. The `_lifecycle` `export -f` bug and the `lifecycle-add-cleanup` naming mismatch are worth fixing regardless of the broader decision, since they affect the "good" half of the codebase and are currently invisible only because of blanket `2>/dev/null || true` error suppression at every call site.
