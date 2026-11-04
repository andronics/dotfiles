#!/usr/bin/env zsh
# Tests for `lockscreen sleep-lock`, the locker xss-lock.service runs before
# sleep with logind's delay inhibitor in XSS_SLEEP_LOCK_FD: it closes the fd
# once the locker is up, closes it after the timeout when the locker never
# comes, and starts no second lock when i3lock already runs.
#
# Nothing locks: betterlockscreen and pgrep are stubs on PATH. The "locker"
# is a marker file that the betterlockscreen stub creates; pgrep reports it.
# The inhibitor is a fifo whose reader stamps whether the locker was up when
# the last writer closed it. The dispatcher runs under zsh -f with DOTLIB at
# this repo's dotlib, so no rc file or live dotlib is read.
#
#   zsh tests/lockscreen-sleep-lock.zsh

emulate -L zsh
setopt no_unset
zmodload zsh/datetime

unset XSS_SLEEP_LOCK_FD
typeset -r REPO=${0:A:h:h}
mkdir -p ~/.cache || exit 1
typeset -r S=$(mktemp -d ~/.cache/lockscreen-sleep-lock-test.XXXXXX)
[[ -d $S ]] || exit 1
typeset -r UP=$S/locker-up CALLS=$S/calls
integer fail=0
ok()  { print "ok   $1"; }
bad() { (( ++fail )); print "FAIL $1${2:+: $2}"; }

mkdir -p $S/stub
# betterlockscreen: logs its call and whether it inherited the inhibitor fd,
# then (unless LOCKER_NEVER) "starts i3lock" after LOCKER_DELAY seconds.
print -r -- '#!/bin/zsh
fd=${XSS_SLEEP_LOCK_FD:-}
if [[ -n $fd && $(readlink /proc/$$/fd/$fd 2>/dev/null) == "'$S'/inhibitor" ]]; then print "betterlockscreen $* fd-leaked"; else print "betterlockscreen $*"; fi >>"'$CALLS'"
[[ -n ${LOCKER_NEVER:-} ]] && exit 0
sleep ${LOCKER_DELAY:-0.3}
: >"'$UP'"' >$S/stub/betterlockscreen
print -r -- '#!/bin/sh
[ -e "'$UP'" ]' >$S/stub/pgrep
chmod +x $S/stub/*

export PATH=$S/stub:$PATH DOTLIB=$REPO/shell/.local/share/dotlib
export TOOL_JOURNAL=off TOOL_STATS=skip LOCKSCREEN_SLEEP_TIMEOUT=1

# Runs sleep-lock with a fresh inhibitor fd; sets REPLY to the reader's
# stamp ("up" or "down": the locker's state when the fd was released) and
# reply to (exit status, seconds taken).
run() {
    local fifo=$S/inhibitor stamp=$S/released fd
    local -F t0=$EPOCHREALTIME
    rm -f $S/inhibitor $S/released
    mkfifo $fifo
    { cat $fifo >/dev/null; if [[ -e $UP ]]; then print up; else print down; fi >$stamp } &
    local reader=$!
    exec {fd}>$fifo
    XSS_SLEEP_LOCK_FD=$fd zsh -f $REPO/desktop/.local/bin/lockscreen sleep-lock >>$S/out 2>&1 &
    local job=$!
    exec {fd}>&-
    wait $job; local st=$?
    wait $reader
    reply=($st $(( EPOCHREALTIME - t0 )))
    REPLY=$(<$stamp)
}

# 1. The locker comes up: the fd is released after it, not before.
rm -f $UP $CALLS; run
[[ $REPLY == up ]] && ok "releases the fd once the locker is up" || bad "releases after the locker" "stamp $REPLY"
(( reply[1] == 0 )) && ok "exits 0 when the locker came up" || bad "exit status" "${reply[1]}"
[[ $(<$CALLS) == "betterlockscreen --lock -- -n" ]] && ok "locks once, without the inhibitor fd" || bad "lock call" "$(<$CALLS)"

# 2. The locker never appears: released after the timeout, status 1.
rm -f $UP $CALLS; LOCKER_NEVER=1 run
[[ $REPLY == down ]] && ok "releases the fd when the locker never comes" || bad "timeout release" "stamp $REPLY"
(( reply[1] == 1 )) && ok "exits 1 after the timeout" || bad "timeout status" "${reply[1]}"
(( reply[2] >= 1 && reply[2] < 3 )) && ok "gives up after about LOCKSCREEN_SLEEP_TIMEOUT" || bad "timeout length" "${reply[2]}s"

# 3. i3lock already runs (the power menu locked first): no second lock, and
# the fd is released at once.
rm -f $CALLS; : >$UP; run
[[ ! -e $CALLS ]] && ok "starts no second lock" || bad "second lock" "$(<$CALLS)"
[[ $REPLY == up ]] && (( reply[1] == 0 && reply[2] < 0.5 )) && ok "releases at once" || bad "immediate release" "$REPLY ${reply[*]}"

# 4. No fd (loginctl lock-session): still locks and waits for the locker.
rm -f $UP $CALLS
zsh -f $REPO/desktop/.local/bin/lockscreen sleep-lock >>$S/out 2>&1; st=$?
(( st == 0 )) && [[ -e $UP && $(<$CALLS) == "betterlockscreen --lock -- -n" ]] && ok "locks without an fd" || bad "no-fd lock" "status $st"

wait
rm -rf -- "${S:?}"
(( fail )) && { print "$fail failed"; exit 1; }
print "all passed"
