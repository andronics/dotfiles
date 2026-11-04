#!/usr/bin/env zsh
# Tests for the tmux guard shim (shell/.local/bin/tmux) on private servers
# only: every call names -L guardtest / -L guardtest-other, or sets $TMUX to
# guardtest's socket. Nothing here can reach the default server.
#
#   zsh tests/tmux-guard.zsh

emulate -L zsh
setopt no_unset

unset TMUX TMUX_PANE TMUX_FORCE COORD_STOP
typeset -r REPO=${0:A:h:h}
typeset -r REAL=/usr/bin/tmux
typeset -r L=guardtest L2=guardtest-other
typeset -r SOCK="${TMUX_TMPDIR:-/tmp}/tmux-${UID}/${L}"
typeset -r SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/tmux-guard-test.XXXXXX")
typeset -r LOGFILE=$SCRATCH/logger.out

mkdir -p $SCRATCH/stub
print -r -- '#!/bin/sh
printf "%s\n" "$*" >>"'$LOGFILE'"' >$SCRATCH/stub/logger
chmod +x $SCRATCH/stub/logger

export TMUX_GUARD_DEFAULT_SOCKET=$SOCK
export DOTLIB=$REPO/shell/.local/share/dotlib
export PATH="$REPO/shell/.local/bin:$SCRATCH/stub:$PATH"

integer pass=0 fail=0
typeset err out
cleanup() {
    $REAL -L $L kill-server 2>/dev/null || true
    $REAL -L $L2 kill-server 2>/dev/null || true
    rm -rf $SCRATCH
}
trap cleanup EXIT

ok()  { (( ++pass )); print "ok   $1"; }
bad() { (( ++fail )); print "FAIL $1${2:+: $2}"; }

# kill-server returns before the server has gone; a new-session in that gap
# meets "server exited unexpectedly".
stop() {
    local sock="${SOCK:h}/$1" i
    $REAL -L $1 kill-server 2>/dev/null || true
    for i in {1..100}; do [[ -S $sock ]] || return 0; sleep 0.02; done
}

# apps-coordinator: 1 window, 1 pane. multi-coordinator: 2 windows, the first
# with 2 panes. plain: not a coordinator.
fixture() {
    stop $L; stop $L2
    $REAL -f /dev/null -L $L new-session -d -s apps-coordinator -x 80 -y 24 'sleep 100000'
    $REAL -L $L new-session -d -s multi-coordinator -x 80 -y 24 'sleep 100000'
    $REAL -L $L split-window -d -t multi-coordinator: 'sleep 100000'
    $REAL -L $L new-window -d -t multi-coordinator: 'sleep 100000'
    $REAL -L $L new-session -d -s plain -x 80 -y 24 'sleep 100000'
    : >$LOGFILE
}
sessions() { $REAL -L $L list-sessions -F '#S' 2>/dev/null | sort | paste -sd' '; }
count()    { $REAL -L $L $1 -t $2 -F x 2>/dev/null | wc -l; }
ALL="apps-coordinator multi-coordinator plain"

# refused <name> <args...>: exit 1, one stderr line naming the coordinators,
# nothing changed.
refused() {
    local name=$1; shift
    fixture
    local rc=0
    err=$(tmux "$@" 2>&1 >/dev/null) || rc=$?
    local -a lines=("${(@f)err}")
    if (( rc != 1 )); then bad $name "exit $rc ($err)"
    elif [[ $#lines != 1 || $err != *'refused'*'apps-coordinator, multi-coordinator'*'coord stop <name>'*'TMUX_FORCE=1 to override'* ]]; then bad $name "message: $err"
    elif [[ $(sessions) != $ALL || $(count list-windows '=multi-coordinator') != 2 ]]; then bad $name "state changed: $(sessions)"
    elif [[ -s $LOGFILE ]]; then bad $name "logged"
    else ok $name; fi
}

# allowed <name> <expected sessions> <args...>
allowed() {
    local name=$1 want=$2; shift 2
    fixture
    local rc=0
    err=$(tmux "$@" 2>&1 >/dev/null) || rc=$?
    if (( rc != 0 )); then bad $name "exit $rc ($err)"
    elif [[ $(sessions) != $want ]]; then bad $name "sessions now: $(sessions)"
    else ok $name; fi
}

print "== refused"
refused kill-server                     -L $L kill-server
refused kill-server-S                   -S $SOCK kill-server
refused kill-server-joined-L            -L$L kill-server
refused kill-server-combined-flags      -uL $L kill-server
refused kill-server-prefix              -L $L kill-serv
refused kill-session                    -L $L kill-session -t apps-coordinator
refused kill-session-exact              -L $L kill-session -t '=apps-coordinator'
refused kill-session-colon              -L $L kill-session -t apps-coordinator:
refused kill-session-prefix-target      -L $L kill-session -t apps
refused kill-session-joined-t           -L $L kill-session -tapps-coordinator
refused kill-ses-alias                  -L $L kill-ses -t apps-coordinator
refused kill-session-a                  -L $L kill-session -a -t plain
refused kill-session-at                 -L $L kill-session -at plain
refused kill-window-last                -L $L kill-window -t apps-coordinator:0
refused killw-last                      -L $L killw -t '=apps-coordinator'
refused kill-pane-last                  -L $L kill-pane -t apps-coordinator:0.0
refused killp-last                      -L $L killp -t '=apps-coordinator:'
refused kill-pane-id                    -L $L kill-pane -t %0   # apps-coordinator's pane, first made
refused chain-escaped                   -L $L display -p hi ';' kill-server
refused chain-trailing                  -L $L list-sessions';' kill-session -t apps-coordinator
refused chain-second-runs-nothing       -L $L new-session -d -s extra ';' killw -t apps-coordinator

# Inside tmux: no -L/-S, $TMUX names the socket, the current session is the
# one holding $TMUX_PANE.
inside() {
    local pane=$($REAL -L $L list-panes -t "=$1" -F '#{pane_id}' | head -1)
    local pid=$($REAL -L $L display -p '#{pid}')
    TMUX="$SOCK,$pid,0" TMUX_PANE=$pane tmux "${@:2}"
}
[[ -n $SOCK && $SOCK == *$L ]] || { print "bad socket $SOCK"; exit 1; }
fixture; rc=0; err=$(inside apps-coordinator kill-session 2>&1) || rc=$?
[[ $rc == 1 && $err == *'refused kill-session of apps-coordinator'* && $(sessions) == $ALL ]] \
    && ok inside-kill-session-current || bad inside-kill-session-current "$rc $err"
fixture; rc=0; err=$(inside apps-coordinator kill-server 2>&1) || rc=$?
[[ $rc == 1 && $(sessions) == $ALL ]] && ok inside-kill-server || bad inside-kill-server "$rc $err"
fixture; rc=0; err=$(inside plain kill-session 2>&1) || rc=$?
[[ $rc == 0 && $(sessions) == "apps-coordinator multi-coordinator" ]] \
    && ok inside-kill-session-plain || bad inside-kill-session-plain "$rc $err $(sessions)"

print "== allowed"
allowed kill-session-plain "apps-coordinator multi-coordinator" -L $L kill-session -t plain
allowed kill-session-C "$ALL" -L $L kill-session -C -t apps-coordinator
fixture; tmux -L $L kill-window -t multi-coordinator:1 && [[ $(count list-windows '=multi-coordinator') == 1 ]] \
    && ok kill-window-not-last || bad kill-window-not-last
fixture; tmux -L $L killp -t multi-coordinator:0.1 && [[ $(count list-panes multi-coordinator:0) == 1 ]] \
    && ok kill-pane-not-last || bad kill-pane-not-last
fixture; tmux -L $L kill-pane -a -t apps-coordinator && ok kill-pane-a || bad kill-pane-a
fixture; tmux -L $L kill-window -a -t '=apps-coordinator' && ok kill-window-a || bad kill-window-a
fixture; out=$(tmux -L $L list-sessions -F '#S' | sort | paste -sd' ')
[[ $out == $ALL ]] && ok pass-through-list || bad pass-through-list "$out"
[[ $(tmux -V) == $($REAL -V) ]] && ok pass-through-version || bad pass-through-version
fixture; rc=0; err=$(tmux -L $L kill -t plain 2>&1) || rc=$?
[[ $rc != 0 && $err == *ambiguous* && $(sessions) == $ALL ]] && ok ambiguous-left-to-tmux || bad ambiguous-left-to-tmux "$err"

# A server with no coordinators.
stop $L
$REAL -f /dev/null -L $L new-session -d -s plain 'sleep 100000'; : >$LOGFILE
tmux -L $L kill-server && ! $REAL -L $L has-session 2>/dev/null && [[ ! -s $LOGFILE ]] \
    && ok no-coordinators-kill-server || bad no-coordinators-kill-server

# Another server: straight through, not logged.
fixture; $REAL -f /dev/null -L $L2 new-session -d -s other-coordinator 'sleep 100000'
tmux -L $L2 kill-server && ! $REAL -L $L2 has-session 2>/dev/null && [[ ! -s $LOGFILE && $(sessions) == $ALL ]] \
    && ok other-server-kill-server || bad other-server-kill-server

print "== overrides"
fixture; TMUX_FORCE=1 tmux -L $L kill-session -t apps-coordinator \
    && [[ $(sessions) == "multi-coordinator plain" && $(<$LOGFILE) == '-t tmux-guard kill-session of apps-coordinator (TMUX_FORCE=1) by '* ]] \
    && ok tmux-force || bad tmux-force "$(<$LOGFILE)"
fixture; COORD_STOP=1 tmux -L $L kill-server \
    && ! $REAL -L $L has-session 2>/dev/null && [[ $(<$LOGFILE) == '-t tmux-guard kill-server (COORD_STOP=1) by '* ]] \
    && ok coord-stop || bad coord-stop "$(<$LOGFILE)"
# The stop script calls subprocess.run(["tmux", "kill-session", ...]) and
# sets nothing; its command line lets it through.
mkdir -p $SCRATCH/brain
print -r -- 'import subprocess, sys
sys.exit(subprocess.run(["tmux", "-L", "'$L'", "kill-session", "-t", "=apps-coordinator"]).returncode)' \
    >$SCRATCH/brain/coordinator-stop.py
fixture; python3 $SCRATCH/brain/coordinator-stop.py \
    && [[ $(sessions) == "multi-coordinator plain" && $(<$LOGFILE) == *'(coordinator-stop.py) by python3/'* ]] \
    && ok stop-script-parent || bad stop-script-parent "$(<$LOGFILE)"

print "== no recursion"
mkdir -p $SCRATCH/a $SCRATCH/b
cp $REPO/shell/.local/bin/tmux $SCRATCH/a/tmux; ln -s $REPO/shell/.local/bin/tmux $SCRATCH/b/tmux
out=$(PATH="$SCRATCH/a:$SCRATCH/b:$PATH" timeout 5 tmux -V) && [[ $out == $($REAL -V) ]] \
    && ok no-recursion || bad no-recursion "$out"
fixture; out=$(PATH="$SCRATCH/b:$SCRATCH/a:$PATH" timeout 5 tmux -L $L kill-server 2>&1 || true)
[[ $out == *refused* ]] && ok no-recursion-guarded || bad no-recursion-guarded "$out"

print "== timing (pass-through, 200 calls each)"
fixture
t() {
    local s=$EPOCHREALTIME i
    for i in {1..200}; do "$@" >/dev/null; done
    printf '%.2f' $(( (EPOCHREALTIME - s) * 1000 / 200 ))
}
zmodload zsh/datetime
real_ms=$(t $REAL -L $L display -p x); shim_ms=$(t tmux -L $L display -p x)
print "real ${real_ms}ms, shim ${shim_ms}ms per call"
(( shim_ms - real_ms < 10 )) && ok timing || bad timing "adds $(( shim_ms - real_ms ))ms"

print "\n$pass passed, $fail failed"
(( fail == 0 ))
