#!/usr/bin/env zsh

# ------------------------------

_xinitrc() {

    echo "running x session wrapper"

    # load resources
    for _file in "/etc/X11/Xresources" "${HOME}/.Xresources"; do
        [[ -f "${_file}" ]] && {
            echo "loading resource: ${_file}"
            xrdb -merge "${_file}"
        }
    done

    # load keymaps
    for _file in "/etc/X11/Xkbmap" "$HOME/.Xkbmap"; do
        [[ -f "${_file}" ]] && {
            echo "loading keymap: ${_file}"
            setxkbmap `cat "${_file}"`
            XKB_IN_USE=yes
        }
    done

    # load xmodmap if not using XKB
    [[ -z "${XKB_IN_USE}" ]] && {
        for _file in "/etc/X11/Xmodmap" "$HOME/.Xmodmap"; do
            [[ -f "${_file}" ]] && {
               echo "loading modmap: ${_file}"
               xmodmap "${_file}"
            }
        done
    }
    unset XKB_IN_USE

    # Run all system xinitrc shell scripts.
    _xinitdir="/etc/X11/xinit/xinitrc.d"
    [[ -d "${_xinitdir}" ]] && {
        for _file in ${_xinitdir}/*; do
            [[ -x "${_file}" && ! -d "${_file}" ]] && {
                echo "loading xinit script ${_file}"
                . "${_file}"
            }
        done
    }

    echo "session wrapper complete, running session"
    exec dbus-launch --exit-with-session /usr/bin/bspwm

}

# ------------------------------

_xinitrc &> ~/.xlog
