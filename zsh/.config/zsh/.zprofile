umask 022

# ------------------------------

[[ $- != *i* ]] && setxkbmap -layout gb

# ------------------------------

export DOTFILES="${HOME}/.dotfiles"

# ------------------------------

export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_STATE_HOME="${HOME}/.local/state"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# ------------------------------

export BROWSER=/usr/bin/google-chrome-stable
export CODEEDITOR=code
export COLORTERM=alacritty
export EDITOR=nano
export GUI_EDITOR=code
export PAGER=less
export READER=zathura
export TERMINAL=alacritty
export TERM=xterm-256color
export VISUAL=code
export WM=bspwm

# ------------------------------

export HISTFILE=${ZDOTDIR}/.zsh_history
export HISTSIZE=10000
export SAVEHIST=10000

# ------------------------------

export DISABLE_UPDATE_PROMPT=true
export UPDATE_ZSH_DAYS=28
export ZSH="${HOME}/.oh-my-zsh"

# ------------------------------

export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus" # Temporary Patch 

# ------------------------------

export GOBIN="${HOME}/.go/bin"
export GOPATH="${HOME}/.go"

# ------------------------------

export GPG_TTY=$(tty)

# ------------------------------

export GTK2_RC_FILES="${XDG_CONFIG_HOME}/gtk-2.0/gtkrc"

# ------------------------------

export NPM_CONFIG_PREFIX="${HOME}/.local"

# ------------------------------

export OLDPATH="${OLDPATH:-${PATH}}"
export PATH="${OLDPATH}:${GOBIN}"

# ------------------------------

[[ $- != *i* ]] && {
    
    export HOST_RESOLUTION=$(xdpyinfo | awk '/dimensions/ {print $2}')
    export HOST_MONITOR=$(xrandr | awk '/ connected/ {print $1}')
    export WINDOW_GAP="20"
    export WINDOW_PADDING="20"

}

