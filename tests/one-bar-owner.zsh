#!/usr/bin/env zsh
# One bar owner (dotfiles record 0003 §B7): barctl, from andronics/desktop-tools,
# is the only program that talks to polybar. Fails when any tracked file under
# shell/ or desktop/ runs `polybar-msg`, except dotlib's _coord, which is
# exempt until crew lands (the brain's ruling on record 0003's cut-over: crew
# moves the coordinator strip onto barctl, and _coord-poke goes with it).
# Comments don't count: a line whose first non-blank character is # or ;, and
# the rest of a line after a blank and a #.
#
# First checks the scan itself on a scratch tree (a planted use is caught; a
# comment, the exempt file and a binary file are not), then scans the repo.
# Reads files only; runs nothing on the desktop.
#
#   zsh tests/one-bar-owner.zsh

emulate -L zsh
setopt no_unset extended_glob

typeset -r REPO=${0:A:h:h}
typeset -r EXEMPT=shell/.local/share/dotlib/_coord
integer fail=0
ok()  { print "ok   $1"; }
bad() { (( ++fail )); print "FAIL $1${2:+: $2}"; }

# REPLY = "<file>:<line>: <text>" for each use of polybar-msg in files $2..
# (relative to root $1) that isn't a comment, one per line; empty when none.
uses() {
    local root=$1 f line
    local -i n
    local -a found
    shift
    for f in "$@"; do
        [[ $f == $EXEMPT ]] && continue
        [[ -f $root/$f ]] || continue
        grep -Iq -- polybar-msg $root/$f 2>/dev/null || continue
        n=0
        while IFS= read -r line || [[ -n $line ]]; do
            (( ++n ))
            [[ $line == [[:space:]]#[\#\;]* ]] && continue
            line=${line%%[[:space:]]\#*}
            [[ $line == *polybar-msg* ]] && found+=("$f:$n: ${line##[[:space:]]#}")
        done < $root/$f
    done
    REPLY=${(F)found}
}

# The scan, on a scratch tree.
mkdir -p ~/.cache || exit 1
typeset -r S=$(mktemp -d ~/.cache/one-bar-owner-test.XXXXXX) || exit 1
trap 'rm -rf -- "${S:?}"' EXIT
mkdir -p $S/desktop/bin $S/shell/.local/share/dotlib $S/desktop/.config/polybar
print -rl -- '#!/bin/sh' 'polybar-msg cmd hide' > $S/desktop/bin/planted
print -rl -- '#!/bin/sh' '    timeout 2 polybar-msg -p 1 action x >/dev/null' > $S/desktop/bin/planted-indented
print -rl -- '#!/bin/sh' '# polybar-msg cmd hide, in a comment' 'echo hi  # polybar-msg in a trailing comment' > $S/desktop/bin/commented
print -rl -- '; `polybar-msg action coord hook 0` in an ini comment' 'hook-0 = coord bar' > $S/desktop/.config/polybar/c.ini
print -rl -- 'polybar-msg action coord hook 0' > $S/$EXEMPT
printf 'polybar-msg\0binary\n' > $S/desktop/bin/binary
uses $S desktop/bin/planted desktop/bin/planted-indented desktop/bin/commented \
    desktop/.config/polybar/c.ini $EXEMPT desktop/bin/binary
[[ $REPLY == "desktop/bin/planted:2: polybar-msg cmd hide"$'\n'"desktop/bin/planted-indented:2: timeout 2 polybar-msg -p 1 action x >/dev/null" ]] \
    && ok "the scan catches both planted uses and skips comments, _coord and binary files" \
    || bad "the scan on a scratch tree" "${REPLY:-nothing found}"

# The repo.
local -a files
files=(${(f)"$(git -C $REPO ls-files -- shell desktop)"})
(( ${#files} > 100 )) && ok "${#files} tracked files under shell/ and desktop/" \
    || bad "too few tracked files to scan" "${#files}"
[[ -f $REPO/$EXEMPT ]] && grep -q 'polybar-msg action coord hook 0' $REPO/$EXEMPT \
    && ok "_coord still pokes its strip directly (exempt until crew)" \
    || bad "_coord no longer runs polybar-msg: drop its exemption here"
uses $REPO "${files[@]}"
[[ -z $REPLY ]] && ok "no tracked file but _coord runs polybar-msg" \
    || bad "polybar-msg outside barctl and _coord" $'\n'"$REPLY"

(( fail )) && { print "$fail failed"; exit 1; }
print "all passed"
