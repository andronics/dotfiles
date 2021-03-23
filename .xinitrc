#!/bin/sh

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
    for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
        [ -x "$f" ] && . "$f"
    done
    unset f
fi

# Start session services, which may include WM, hotkey daemon, screen locker, etc.
exec dbus-run-session -- runsvdir -P $HOME/.local/services

