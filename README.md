# dotfiles

Stow-managed dotfiles organized into three composable profiles.

## Layout

| Package | What it is | When to install |
|---------|-----------|-----------------|
| `shell/` | zsh + integrations (autosuggestions, syntax-highlighting, fzf-tab, fzf, dircolors, starship, zoxide, deno, pnpm, docker, gpg-agent, etc.), tmux + tmuxinator, gnupg keys, ssh keys, git config, gh config | Always — including servers |
| `desktop/` | bspwm + sxhkd + bsp helpers, polybar, picom, dunst, rofi, alacritty, gtk 2/3/4, X11 (.xinitrc, .Xresources), backgrounds, themes, palette, X-session boot scripts in `.zlogin.d/` | Linux desktops only |
| `optional/` | Claude Code config, neofetch, ranger, spotifyd | Per-machine opt-in |

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
                        zoxide starship fzf eza bat \
                        zsh-autosuggestions zsh-syntax-highlighting
paru   -S --needed fzf-tab

# desktop (if installing desktop/)
sudo pacman -S --needed bspwm sxhkd polybar picom dunst rofi gtk3 \
                        alacritty papirus-icon-theme feh nemo

# optional
sudo pacman -S --needed neofetch ranger spotifyd
```

```sh
./dotfiles install shell                        # server
./dotfiles install shell desktop                # workstation
./dotfiles install shell desktop optional       # everything
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

`shell/.postinstall` enforces `chmod 700` on `~/.ssh` and `~/.gnupg` (sshd and gpg refuse loose-perm dirs) and runs `gpg-connect-agent reloadagent` so any newly-imported keys are picked up.

## Secrets architecture

Three layered tiers. Compromise of any tier leaks nothing without the one above it.

```
GPG key             ← shell/.gnupg submodule (private)
   │ decrypts
pass entries        ← github.com/andronics/password-store (private)
   │ pass show git/crypt-key
git-crypt key       ← 32-byte symmetric key, never on disk in plaintext
   │ AES via git clean/smudge
*.env files         ← tracked in this (public) repo
```

Patterns under git-crypt are declared in `.gitattributes` at the repo root. The clean/smudge filters are wired automatically by `shell/.postinstall` on first install — it runs `./shell/.local/bin/git-crypt init` if `.gitattributes` declares the filter and `.git/config` doesn't yet have it.

To wire manually (after `pass` and the key are available):

```sh
cd ~/.dotfiles && ./shell/.local/bin/git-crypt init
git checkout HEAD -- .       # re-checkout to materialize decrypted contents
```

Currently no files are encrypted — the wiring is symbolic. Add a pattern to `.gitattributes` and re-add the matching files (`git rm --cached <file>; git add <file>`) to start encrypting.

> The `git-crypt` script in this repo is a custom openssl-based implementation, not Andrew Ayer's upstream `git-crypt` Arch package. Same clean/smudge concept; symmetric-only; deliberate.

## Conventions

- **zsh dispatcher**: `shell/.config/zsh/{.zshenv,.zshrc,.zprofile,.zlogin,.zlogout}` each loop over a matching `*.d/` directory and source files in numeric order. Drop a `NN-name` file into the right `.zXXX.d/` to add behaviour.
  - `00–09` early environment / cache priming
  - `10–49` PATH and tool init
  - `50` aliases, functions, settings
  - `60–89` plugin sources
  - `90–99` runs-last (syntax highlighting must be `99`)
- **Desktop X-session boot** lives in `desktop/.config/zsh/.zlogin.d/`. Stowing `desktop` activates polybar, picom, dunst, polkit-agent, sxhkd, feh, x11. Stowing only `shell` does not.
- **Per-host opt-ins** go in `optional/`. Don't put desktop-essential tools (terminal emulator, launcher) here.

## Profiles cheat sheet

```
server:        shell
linux desktop: shell desktop
workstation:   shell desktop optional
```
