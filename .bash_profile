umask 022

export BROWSER="/opt/google/chrome/chrome"
export CODEEDITOR="code"
export COLORTERM="termite"
export EDITOR="nano"
export GTK2_RC_FILES="$HOME/.config/gtk-2.0/.gtkrc-2.0"
export GUI_EDITOR="code"
export PAGER="less"
export READER="zathura"
export TERMINAL="termite"
export VISUAL="nano"
export WM="bspwm"

# wallpaper colors
(wal -r &)

if [[ "$(tty)" = "/dev/tty1" ]]; then
	pgrep i3 || startx
fi
