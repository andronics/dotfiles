#!/usr/bin/env zsh
# One bar owner (dotfiles record 0003 §B7): barctl, from andronics/desktop-tools,
# is the only program that talks to polybar. Fails when any tracked file under
# shell/ or desktop/ runs `polybar-msg`. No file is exempt: the coordinator
# strip, the last to poke polybar itself, is drawn through barctl since crew
# replaced coord (brain record 0019 §9).
# Comments don't count: a line whose first non-blank character is # or ;, and
# the rest of a line after a blank and a #.
#
# First checks the scan itself on a scratch tree (a planted use is caught; a
# comment and a binary file are not), then scans the repo.
# Reads files only; runs nothing on the desktop.
#
#   zsh tests/one-bar-owner.zsh

emulate -L zsh
setopt no_unset extended_glob

typeset -r REPO=${0:A:h:h}
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
mkdir -p $S/desktop/bin $S/desktop/.config/polybar
print -rl -- '#!/bin/sh' 'polybar-msg cmd hide' > $S/desktop/bin/planted
print -rl -- '#!/bin/sh' '    timeout 2 polybar-msg -p 1 action x >/dev/null' > $S/desktop/bin/planted-indented
print -rl -- '#!/bin/sh' '# polybar-msg cmd hide, in a comment' 'echo hi  # polybar-msg in a trailing comment' > $S/desktop/bin/commented
print -rl -- '; `polybar-msg action crew hook 0` in an ini comment' 'hook-0 = barctl render crew' > $S/desktop/.config/polybar/c.ini
printf 'polybar-msg\0binary\n' > $S/desktop/bin/binary
uses $S desktop/bin/planted desktop/bin/planted-indented desktop/bin/commented \
    desktop/.config/polybar/c.ini desktop/bin/binary
[[ $REPLY == "desktop/bin/planted:2: polybar-msg cmd hide"$'\n'"desktop/bin/planted-indented:2: timeout 2 polybar-msg -p 1 action x >/dev/null" ]] \
    && ok "the scan catches both planted uses and skips comments and binary files" \
    || bad "the scan on a scratch tree" "${REPLY:-nothing found}"

# The repo.
local -a files
files=(${(f)"$(git -C $REPO ls-files -- shell desktop)"})
(( ${#files} > 100 )) && ok "${#files} tracked files under shell/ and desktop/" \
    || bad "too few tracked files to scan" "${#files}"
uses $REPO "${files[@]}"
[[ -z $REPLY ]] && ok "no tracked file runs polybar-msg" \
    || bad "polybar-msg outside barctl" $'\n'"$REPLY"

(( fail )) && { print "$fail failed"; exit 1; }
print "all passed"
