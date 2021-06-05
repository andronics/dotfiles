# do nothing if not interactive

[[ $- != *i* ]] && return

# shell cmd-line editing

set -o vi

# shell options

shopt -s checkwinsize
shopt -s histappend
shopt -s globstar

# history

HISTSIZE=1000
HISTFILESIZE=2000
HISTCONTROL=ignoreboth

# jump support

eval "$(jump shell --bind=j)"

# wallpaper colors
(wal -r &)

# aliases
source $HOME/.aliases