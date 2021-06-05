umask 022

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Shared Configuration
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

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

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# DEFAULT
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

export HOST_RESOLUTION=$(xdpyinfo | awk '/dimensions/ {print $2}')
export HOST_MONITOR=$(xrandr | awk '/ connected/ {print $1}')
export WINDOW_GAP="20"
export WINDOW_PADDING="10"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
# Host Configuration
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #


case $(hostname) in
    desktop)
        export HOST_RESOLUTION="5120x1440"
        export HOST_MONITOR="DP-2"
        ;;
    laptop)
        export HOST_RESOLUTION=${HOST_RESOULTION:-"1600x900"}
		export HOST_MONITOR=${HOST_MONITOR:-"LVDS"}
        ;;
    *) ;;
esac

nvidia-settings --assign CurrentMetaMode="${HOST_RESOLUTION} +0+0 { ForceCompositionPipeline = On, ForceFullCompositionPipeline = On }"

# wallpaper colors
wal -qi ~/.config/wall.jpg

if [[ "$(tty)" = "/dev/tty1" ]]; then
	pgrep i3 || startx
fi
