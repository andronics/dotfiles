# Claude Code project instructions

This repo is the user's personal dotfiles. Read this before making changes.

## Shape

GNU Stow + two composable profiles:

| Package | Always install? | Contents |
|---|---|---|
| `shell/` | yes (servers too) | zsh dispatcher, tmux, gh, git, gpg/ssh keys (private submodules), starship, fzf, dotlib, neofetch |
| `desktop/` | desktops only | bsp, sxhkd, polybar, picom, dunst, rofi, alacritty, X-session boot |

`./dotfiles install <pkg...>` is a thin Stow wrapper. Subcommands: `install` (`i`), `uninstall` (`u`), `reinstall` (`r`), `completions` (`c`: regenerate the dispatchers' zsh completions after changing a module's commands). Per-package hooks: `.preinstall` / `.postinstall` (sourced — they share the wrapper's `err`/`info`/`ok`/`warn` helpers and the `dotfiles_source_root` / `_pkg` vars).

## Editing rule

**Edit files inside this repo, never under `$HOME` directly.** `$HOME` files are stow symlinks back into the repo. Touching `~/.zshrc` directly modifies the symlink target — it works, but a future `./dotfiles reinstall` may rewrite it from scratch, and changes won't show up in `git status` until you look in the right place.

## zsh dispatcher convention

Each lifecycle hook sources files from a matching `.d/` dir in numeric order:

```
shell/.config/zsh/{.zshenv, .zshrc, .zprofile, .zlogin, .zlogout}
                         ↓             ↓           ↓         ↓        ↓
                      .zshenv.d/   .zshrc.d/  .zprofile.d/ .zlogin.d/ .zlogout.d/
```

Drop `NN-name` files in. Tier convention:

| Tier | Use |
|---|---|
| `00-09` | early environment / cache priming |
| `10-49` | PATH and tool init |
| `50` | aliases, functions, settings |
| `60-89` | plugin sources |
| `90-99` | runs-last (syntax-highlighting **must** be `99`) |

X-session boot lives in `desktop/.config/zsh/.zlogin.d/` and only activates when `desktop` is stowed.

## dotlib

Helper library at `${DOTLIB}` = `${XDG_DATA_HOME}/dotlib`. Modules (`_common`, `_log`, `_git`, `_audio`, …) handle their own deps:

```zsh
source "${DOTLIB}/_common" || { echo "[ERROR] _foo requires _common" >&2; return 1; }
source "${DOTLIB}/_cache"  2>/dev/null || true   # optional
```

Don't add an "auto-loader" — the manual pattern is intentional and works.

Scripts in `shell/.local/bin/` (e.g. `audio`, `player`) should be thin dispatchers over `dotlib` modules, not standalone reimplementations. The wrapper contract — ≤30-line wrapper that sources `_dispatcher` + its `_<module>` and calls `dispatcher-init <name> --route=function` then `dispatcher-execute "$@"` — is documented at `shell/.local/share/dotlib/README.md`. Business logic lives in modules, not in wrapper scripts.

## Bar controller and coordinator switchboard

Stateful polybar icons are `custom/ipc` modules drawn by one controller, `barctl`, with `barmenu` for the bar's rofi menus, and the coordinator switchboard is `crew`. All three are Python, in **andronics/desktop-tools** (design records `docs/design/0003-desktop-tools-in-python.md` and `0001-polybar-ipc-module-taxonomy.md`); nothing of them is in dotlib any more. barctl is the only program that talks to polybar: other code calls `barctl hide`/`unhide` (`_bsp`), `barctl theme` (`_theme`'s polybar reload) or `barctl restart` (`polybar-reload`), never `polybar-msg`, which `tests/one-bar-owner.zsh` checks (no file is exempt).

- **Runs as** `barctl run`, the `barctl.service` user unit (`%h/.local/bin/barctl run`, started by `.zlogin.d/50-barctl`; never a child of polybar, whose leaked pipes freeze its restarts). Each module's one hook is `hook-0 = barctl render <module>` with `initial = 1`; its clicks are `barctl click <module> <button>`, which runs the command from `modules.toml` detached.
- **Config:** `desktop/.config/barctl/modules.toml` (linked to `~/.config/barctl/modules.toml`) replaces the package's default whole; `barctl reload` re-reads it. The menus' rows are the package's `barmenu/menus.toml`.
- **Installed and pinned:** `desktop/.config/desktop-tools/version` holds the version; `desktop/.postinstall` runs `uv tool install --python 3.13 --managed-python "git+https://github.com/andronics/desktop-tools@v<version>"` (skipped when `uv tool list` shows that version, `--reinstall` when another is installed) into `~/.local/bin`, then writes the generated completions (`_barctl_cmd`, `_barmenu_cmd`, `_crew_cmd`) into `shell/.config/zsh/completions` with `desktop-tools completions zsh --out`. To upgrade: bump the version file in a PR, then `./dotfiles reinstall desktop` and `systemctl --user restart barctl.service`.
- **Checks:** `barctl doctor` (each failure with a fix to try), `barctl status`, `barctl watch`.
- **Rollback:** pin the previous version and reinstall. To go back to the zsh controller (before record 0003's cut-over), stop `barctl.service`, `uv tool uninstall desktop-tools`, revert the cut-over PR, `./dotfiles reinstall desktop shell`, start the service, `polybar-reload`.
- **Coordinator switchboard:** `crew` (brain record 0019 §7) keeps one hidden terminal per Claude Code coordinator, docked left or right when shown, and pushes the bar's coordinator strip to barctl's `crew` module (`polybar/modules/crew.ini`; its clicks are `[modules.crew.segment_clicks]` in `modules.toml`). Keys are in `sxhkdrc` (`super + c` is `crew menu`), window rules in `bspwmrc` (classes `crew` and `crew-view`), the full menu's theme is `rofi/themes/crew.rasi`, and the Claude Code hooks in `~/.claude/settings.json` (not in this repo) run `crew status`. crew reads the coordinators from the brain's registry (`meta brain coordinators`): no coordinator's name is written in its files here, which `tests/coordinator-launchers.zsh` checks. `coord`, the old zsh switchboard, is an alias that says "coord is now crew" and runs crew until 2026-12-04; then `desktop/.local/bin/coord` and bspwmrc's `coord` rule go.
- **To add a module:** a source in desktop-tools (its own PR and release), its entry in `modules.toml`, the polybar module as `inherit = module/base-ipc`, `type = custom/ipc`, `hook-0 = barctl render <module>` and `barctl click` lines, and the version bump here.

## Secrets architecture

Three-tier chain: GPG key (private submodule) → `pass` (private repo) → git-crypt symmetric key (in `pass` at `hosts/desktop/dotfiles-git-crypt-key-official`) → encrypted files in this public repo. Official git-crypt; Stephen's GPG key is also a git-crypt user. Design record: `docs/design/0002-official-git-crypt.md`.

Unlocked automatically by `shell/.postinstall`. Patterns declared in `.gitattributes` (currently `*.env`). See README.md "Secrets architecture" for the full diagram.

**Never commit a git-crypt file unencrypted** (the repo is public). `.githooks/pre-commit` refuses it; don't bypass it with `--no-verify`. Never run `git-crypt init` here (it would make a new key).

**Do not put files behind git-crypt that are read by the zsh dispatcher chain.** Login shells before bootstrap step 5 would see binary garbage.

## Validation

| Change to | Smoke test |
|---|---|
| `dotfiles` wrapper | `bash -n dotfiles` |
| `.zXXX.d/*` | `zsh -n <file>`; `time zsh -ic exit` (regression check) |
| desktop boot | login on a 2nd TTY; `pgrep -c dunst sxhkd picom polybar` should each be `1` |
| theme | `theme get bg` returns hex; `theme check` passes; `theme self-test` passes; `theme get wallpaper` is a readable image; `theme pick --dry-run` (super + alt + space) shows every scheme with its colours and prints the command instead of applying it; visually scan polybar / rofi / dunst / alacritty |
| git-crypt | `./dotfiles check-crypt` passes; `git-crypt status -e` lists no `NOT ENCRYPTED` warning; `git config core.hooksPath` is `.githooks` |

## House style

- Prefer Stow profile composition over chezmoi-style templating. `gomplate` is the templating escape hatch (`.gomplate/plugins.yml` is wired to `pass`) for the rare files that need per-host variants.
- Don't add comments that restate code. Comments belong on non-obvious *why* (constraints, workarounds, surprising behaviour).
