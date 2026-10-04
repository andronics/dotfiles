# Claude Code project instructions

This repo is the user's personal dotfiles. Read this before making changes.

## Shape

GNU Stow + two composable profiles:

| Package | Always install? | Contents |
|---|---|---|
| `shell/` | yes (servers too) | zsh dispatcher, tmux, gh, git, gpg/ssh keys (private submodules), starship, fzf, dotlib, neofetch |
| `desktop/` | desktops only | bsp, sxhkd, polybar, picom, dunst, rofi, alacritty, X-session boot |

`./dotfiles install <pkg...>` is a thin Stow wrapper. Subcommands: `install` (`i`), `uninstall` (`u`), `reinstall` (`r`). Per-package hooks: `.preinstall` / `.postinstall` (sourced — they share the wrapper's `err`/`info`/`ok`/`warn` helpers and the `dotfiles_source_root` / `_pkg` vars).

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

## Secrets architecture

Three-tier chain: GPG key (private submodule) → `pass` (private repo) → git-crypt symmetric key (in `pass`) → encrypted files in this public repo.

Wired automatically by `shell/.postinstall`. Patterns declared in `.gitattributes` (currently `*.env`). See README.md "Secrets architecture" for the full diagram.

**Do not put files behind git-crypt that are read by the zsh dispatcher chain.** Login shells before bootstrap step 5 would see binary garbage.

## Validation

| Change to | Smoke test |
|---|---|
| `dotfiles` wrapper | `bash -n dotfiles` |
| `.zXXX.d/*` | `zsh -n <file>`; `time zsh -ic exit` (regression check) |
| desktop boot | login on a 2nd TTY; `pgrep -c dunst sxhkd picom polybar` should each be `1` |
| theme | `palette base` returns hex; visually scan polybar / rofi / dunst / alacritty |
| git-crypt | `git check-attr filter -- foo.env` returns `git-crypt`; `.git/config` has `filter.git-crypt.{clean,smudge}` pointing at the real script path |

## House style

- Prefer Stow profile composition over chezmoi-style templating. `gomplate` is the templating escape hatch (`.gomplate/plugins.yml` is wired to `pass`) for the rare files that need per-host variants.
- The custom `git-crypt` (openssl-based) is deliberate, not a placeholder for the upstream tool.
- Don't add comments that restate code. Comments belong on non-obvious *why* (constraints, workarounds, surprising behaviour).
