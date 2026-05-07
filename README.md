# dotfiles

Stow-managed dotfiles organized into three composable profiles.

## Layout

| Package | What it is | When to install |
|---------|-----------|-----------------|
| `shell/` | zsh + integrations (autosuggestions, syntax-highlighting, fzf-tab, fzf, dircolors, starship, zoxide, deno, pnpm, docker, gpg-agent, etc.), tmux + tmuxinator, gnupg keys, ssh keys, git config, gh config | Always — including servers |
| `desktop/` | bspwm + sxhkd + bsp helpers, polybar, picom, dunst, rofi, alacritty, gtk 2/3/4, X11 (.xinitrc, .Xresources), backgrounds, themes, palette, X-session boot scripts in `.zlogin.d/` | Linux desktops only |
| `optional/` | Claude Code config, neofetch, ranger, spotifyd | Per-machine opt-in |

## Bootstrap

### Fresh machine

```sh
git clone --recurse-submodules https://github.com/andronics/dotfiles ~/.dotfiles
cd ~/.dotfiles
```

Install the system packages first (Arch / pacman shown; translate as needed):

```sh
# core (always)
sudo pacman -S --needed zsh git tmux gnupg pass github-cli git-crypt stow \
                        zoxide starship fzf eza bat \
                        zsh-autosuggestions zsh-syntax-highlighting
paru   -S --needed fzf-tab

# desktop (if installing desktop/)
sudo pacman -S --needed bspwm sxhkd polybar picom dunst rofi gtk3 \
                        alacritty papirus-icon-theme feh nemo

# optional
sudo pacman -S --needed neofetch ranger spotifyd
```

Then stow the profiles you want:

```sh
./dotfiles install shell                        # server
./dotfiles install shell desktop                # workstation
./dotfiles install shell desktop optional       # everything
```

`./dotfiles` is a thin stow wrapper. Subcommands: `install` (`i`), `uninstall` (`u`), `reinstall` (`r`). With no args, acts on every package.

### After updates

```sh
git pull --recurse-submodules
./dotfiles reinstall shell desktop
```

## Submodules

Two secrets repos are tracked as submodules. They live inside `shell/`:

- `shell/.gnupg` → personal GPG keyring
- `shell/.ssh`   → SSH keys + `~/.ssh/config`

A clone without `--recurse-submodules` will leave these empty. Fix with:

```sh
git submodule update --init --recursive
```


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
