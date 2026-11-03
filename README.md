# dotfiles

Stow-managed dotfiles organized into three composable profiles.

## Layout

| Package | What it is | When to install |
|---------|-----------|-----------------|
| `shell/` | zsh + integrations (autosuggestions, syntax-highlighting, fzf-tab, fzf, dircolors, starship, zoxide, deno, pnpm, docker, gpg-agent, etc.), tmux + tmuxinator, gnupg keys, ssh keys, git config, gh config, neofetch | Always — including servers |
| `desktop/` | bsp + sxhkd + bsp helpers, polybar, picom, dunst, rofi, alacritty, gtk 2/3/4, X11 (.xinitrc, .Xresources), backgrounds, themes, palette, X-session boot scripts in `.zlogin.d/` | Linux desktops only |

## Bootstrap

The SSH and GnuPG keys live in **private** submodules at `shell/.ssh` and `shell/.gnupg`. The clone is therefore a 4-step dance:

### 1. Clone-time deps

The minimum you need to authenticate and clone:

```sh
sudo pacman -S --needed git stow github-cli
```

### 2. Authenticate to GitHub

```sh
gh auth login    # browser OAuth; configures git's credential helper
```

This wires the credential helper into git so the submodule clone in step 3 works without a PAT prompt. On a headless server, use `gh auth login --with-token < pat.txt`.

### 3. Clone

```sh
git clone --recurse-submodules https://github.com/andronics/dotfiles ~/.dotfiles
cd ~/.dotfiles
```

If you forgot `--recurse-submodules`, the `shell` package's `.preinstall` hook will detect and fetch them on first install.

### 4. Install everything else, then stow

```sh
# core (always)
sudo pacman -S --needed zsh tmux gnupg pass git-crypt \
                        zoxide starship fzf eza bat neofetch \
                        zsh-autosuggestions zsh-syntax-highlighting
paru   -S --needed fzf-tab

# desktop (if installing desktop/)
sudo pacman -S --needed bspwm sxhkd polybar picom dunst rofi gtk3 \
                        alacritty papirus-icon-theme feh nemo
```

```sh
./dotfiles install shell                        # server
./dotfiles install shell desktop                # workstation
```

`./dotfiles` is a thin stow wrapper. Subcommands: `install` (`i`), `uninstall` (`u`), `reinstall` (`r`). With no args, acts on every package. Per-package `.preinstall` / `.postinstall` hooks run automatically when present.

### 5. (Optional) Switch this repo to SSH

Now that the SSH key is on disk, future `git pull`s can use SSH instead of HTTPS:

```sh
git -C ~/.dotfiles remote set-url origin git@github.com:andronics/dotfiles
```

### After updates

```sh
git -C ~/.dotfiles pull --recurse-submodules
./dotfiles reinstall shell desktop
```

## Submodules

Two private secrets repos are tracked as submodules:

- `shell/.gnupg` → personal GPG keyring
- `shell/.ssh`   → SSH keys + `~/.ssh/config`

`shell/.preinstall` validates they are populated before stow runs and will attempt `git submodule update --init --recursive` to fetch them. If that fails, you almost certainly need to `gh auth login` first.

`shell/.postinstall` enforces `chmod 700` on `~/.ssh` and `~/.gnupg` (sshd and gpg refuse loose-perm dirs) and runs `gpg-connect-agent reloadagent` so any newly-imported keys are picked up, then sets up git-crypt in this repo: it points `core.hooksPath` at `.githooks/` and unlocks a fresh clone with the key from `pass` (see [Secrets architecture](#secrets-architecture)).

## Secrets architecture

Three layered tiers. Compromise of any tier leaks nothing without the one above it.

```
GPG key             ← shell/.gnupg submodule (private)
   │ decrypts
pass entries        ← github.com/andronics/password-store (private)
   │ pass show hosts/desktop/dotfiles-git-crypt-key-official
git-crypt key       ← symmetric key (base64 of `git-crypt export-key`), on disk only in tmpfs while unlocking
   │ AES via git clean/smudge
encrypted files     ← *.env (tracked in this public repo)
```

Encryption is the official [git-crypt](https://www.agwa.name/projects/git-crypt/) (`pacman -S git-crypt`). Patterns are declared in `.gitattributes` at the repo root. The repo has two ways in: the symmetric key in `pass`, and Stephen's GPG key, added as a git-crypt user (its wrapped copy of the key is in `.git-crypt/keys/`, encrypted to that GPG key). `shell/.postinstall` unlocks a fresh clone from `pass` on first install, and warns (without failing the install) if it can't.

To unlock by hand, from a clean working tree:

```sh
cd ~/.dotfiles && git-crypt unlock          # with your GPG key

key=$(mktemp -p "$XDG_RUNTIME_DIR")         # or with the key in pass
pass show hosts/desktop/dotfiles-git-crypt-key-official | base64 -d > "$key" \
   && git-crypt unlock "$key"; shred -u "$key"
```

To encrypt more, add a pattern to `.gitattributes` and re-add the matching files (`git rm --cached <file>; git add <file>`).

Because the repo is public, a plaintext secret must never reach a commit. In a locked clone git-crypt's filter isn't configured and git would commit a matching file as-is, so two checks guard it:

- `.githooks/pre-commit` (installed by `shell/.postinstall` through `core.hooksPath`) refuses a commit if any staged file marked `filter=git-crypt` doesn't start with git-crypt's `\0GITCRYPT\0` header. The other hooks in `.githooks/` hand on to your global hooks dir, which a repo-local `core.hooksPath` would otherwise hide.
- `./dotfiles check-crypt` checks every committed file the same way and runs `git-crypt status -e`.

## Conventions

- **zsh dispatcher**: `shell/.config/zsh/{.zshenv,.zshrc,.zprofile,.zlogin,.zlogout}` each loop over a matching `*.d/` directory and source files in numeric order. Drop a `NN-name` file into the right `.zXXX.d/` to add behaviour.
  - `00–09` early environment / cache priming
  - `10–49` PATH and tool init
  - `50` aliases, functions, settings
  - `60–89` plugin sources
  - `90–99` runs-last (syntax highlighting must be `99`)
- **Desktop X-session boot** lives in `desktop/.config/zsh/.zlogin.d/`. Stowing `desktop` activates polybar, picom, dunst, polkit-agent, sxhkd, feh, x11. Stowing only `shell` does not.

## Profiles cheat sheet

```
server:        shell
linux desktop: shell desktop
```
