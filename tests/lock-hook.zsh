#!/usr/bin/env zsh
# The screen-lock hook (desktop/.config/betterlockscreen/custom-pre.sh), which
# betterlockscreen's prelock sources: it clears gpg-agent's passphrase cache
# (`gpg-connect-agent reloadagent /bye`) and then runs `bsp hide`, and it never
# makes the lock fail, whether gpg-connect-agent fails or is missing.
#
# Sources the hook in /bin/sh and /bin/bash (betterlockscreen's shell) with
# PATH set to a scratch dir of stubs only, so the real gpg-agent, bspwm and
# screen are never touched.
#
#   zsh tests/lock-hook.zsh

emulate -L zsh
setopt no_unset

typeset -r REPO=${0:A:h:h}
typeset -r HOOK=$REPO/desktop/.config/betterlockscreen/custom-pre.sh
integer fail=0
ok()  { print "ok   $1"; }
bad() { (( ++fail )); print "FAIL $1${2:+: $2}"; }

mkdir -p ~/.cache || exit 1
typeset -r S=$(mktemp -d ~/.cache/lock-hook-test.XXXXXX) || exit 1
trap 'rm -rf -- "${S:?}"' EXIT

# stubs <dir> <gpg: ok|fail|absent> <timeout: yes|no>
stubs() {
    local d=$1
    mkdir -p $d
    print -r -- '#!/bin/sh
printf "bsp %s\n" "$*" >>"$LOCK_HOOK_LOG"' >$d/bsp
    case $2 in
        ok)   print -r -- '#!/bin/sh
printf "gpg-connect-agent %s\n" "$*" >>"$LOCK_HOOK_LOG"' >$d/gpg-connect-agent ;;
        fail) print -r -- '#!/bin/sh
printf "gpg-connect-agent %s\n" "$*" >>"$LOCK_HOOK_LOG"
echo "ERR stub failure" >&2
exit 1' >$d/gpg-connect-agent ;;
    esac
    [[ $3 == yes ]] && print -r -- '#!/bin/sh
printf "timeout %s\n" "$1" >>"$LOCK_HOOK_LOG"
shift
exec "$@"' >$d/timeout
    chmod +x $d/*
}

# run <name> <shell>: sources the hook with only the stubs on PATH; sets
# REPLY to its exit status and the log to $S/<name>.log.
run() {
    local d=$S/$1
    : >$S/$1.log
    LOCK_HOOK_LOG=$S/$1.log PATH=$d $2 -c '. "$1"' sh $HOOK >$S/$1.out 2>&1
    REPLY=$?
}

for sh in /bin/sh /bin/bash; do
    [[ -x $sh ]] || { bad "$sh missing"; continue; }
    t=${sh:t}

    stubs $S/$t-ok ok yes
    run $t-ok $sh
    (( REPLY == 0 )) && ok "$t: returns 0" || bad "$t: returns 0" "status $REPLY"
    grep -qx 'gpg-connect-agent reloadagent /bye' $S/$t-ok.log \
        && ok "$t: sends reloadagent" || bad "$t: sends reloadagent" "$(<$S/$t-ok.log)"
    grep -qx 'timeout 2' $S/$t-ok.log \
        && ok "$t: bounded by timeout 2" || bad "$t: bounded by timeout 2" "$(<$S/$t-ok.log)"
    [[ $(tail -n1 $S/$t-ok.log) == 'bsp hide' ]] \
        && ok "$t: bsp hide runs after it" || bad "$t: bsp hide runs after it" "$(<$S/$t-ok.log)"
    [[ ! -s $S/$t-ok.out ]] && ok "$t: prints nothing" || bad "$t: prints nothing" "$(<$S/$t-ok.out)"

    stubs $S/$t-fail fail yes
    run $t-fail $sh
    (( REPLY == 0 )) && ok "$t: returns 0 when gpg-connect-agent fails" \
        || bad "$t: returns 0 when gpg-connect-agent fails" "status $REPLY"
    grep -qx 'bsp hide' $S/$t-fail.log \
        && ok "$t: bsp hide runs when gpg-connect-agent fails" || bad "$t: bsp hide runs when gpg-connect-agent fails"
    [[ ! -s $S/$t-fail.out ]] && ok "$t: failure stays quiet" || bad "$t: failure stays quiet" "$(<$S/$t-fail.out)"

    stubs $S/$t-absent absent yes
    run $t-absent $sh
    (( REPLY == 0 )) && ok "$t: returns 0 when gpg-connect-agent is absent" \
        || bad "$t: returns 0 when gpg-connect-agent is absent" "status $REPLY"
    [[ $(<$S/$t-absent.log) == 'bsp hide' ]] \
        && ok "$t: only bsp hide runs when gpg-connect-agent is absent" \
        || bad "$t: only bsp hide runs when gpg-connect-agent is absent" "$(<$S/$t-absent.log)"

    stubs $S/$t-notimeout ok no
    run $t-notimeout $sh
    (( REPLY == 0 )) && grep -qx 'gpg-connect-agent reloadagent /bye' $S/$t-notimeout.log \
        && grep -qx 'bsp hide' $S/$t-notimeout.log \
        && ok "$t: works without timeout" || bad "$t: works without timeout" "status $REPLY; $(<$S/$t-notimeout.log)"
done

(( fail == 0 )) && print "all passed" || print "$fail failed"
exit $(( fail > 0 ))
