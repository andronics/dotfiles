#!/usr/bin/env zsh
# Tests for the lockscreen verbs barmenu's lock menu runs (desktop-tools
# design record 0001): `hook-disable [duration]` and its resume timer,
# `hook-enable` cancelling it, `status --json`, and `forget-passphrase`.
#
# Nothing real runs: xidlehook-client, pgrep, systemd-run, systemctl,
# gpg-connect-agent, timeout and notify-send are stubs first on PATH that
# log their arguments; the stubs' answers come from files in the scratch
# dir. xidlehook's socket is a socket file nobody listens on. The dispatcher
# runs under zsh -f with DOTLIB at this repo's dotlib, so no rc file or live
# dotlib is read.
#
#   zsh tests/lockscreen-verbs.zsh

emulate -L zsh
setopt no_unset
zmodload zsh/net/socket zsh/datetime

typeset -r REPO=${0:A:h:h}
mkdir -p ~/.cache || exit 1
typeset -r S=$(mktemp -d ~/.cache/lockscreen-verbs-test.XXXXXX)
[[ -d $S ]] || exit 1
trap 'rm -rf -- "${S:?}"' EXIT
typeset -r LOG=$S/calls
integer fail=0
ok()  { print "ok   $1"; }
bad() { (( ++fail )); print "FAIL $1${2:+: $2}"; }

mkdir -p $S/stub
# Each stub logs "<name> <args>" to $LOG, then answers as the files say.
stub() {
    print -r -- "#!/bin/zsh
print -r -- \"$1 \$*\" >>'$LOG'
$2" >$S/stub/$1
    chmod +x $S/stub/$1
}
stub pgrep "[[ -e '$S/running' ]] && print 4242 || exit 1"
stub xidlehook-client "[[ \$* == *query* ]] && { [[ -e '$S/disabled' ]] && print 'disabled: true' || print 'disabled: false'; }; exit 0"
stub systemd-run "exit \$(<'$S/run-rc')"
stub systemctl "[[ \$* == *show* ]] && cat '$S/show'; exit 0"
stub gpg-connect-agent "exit \$(<'$S/gpg-rc')"
stub timeout 'shift; exec "$@"'
stub notify-send 'exit 0'

zsocket -l $S/xidlehook.sock && exec {REPLY}>&-
export PATH=$S/stub:$PATH DOTLIB=$REPO/shell/.local/share/dotlib
export XIDLEHOOK_SOCKET=$S/xidlehook.sock
export TOOL_JOURNAL=off TOOL_STATS=skip NOTIFY_HISTORY_ENABLED=false

# reset: the daemon runs and is armed, no resume timer, every stub succeeds.
reset() {
    : >$LOG; : >$S/running; rm -f $S/disabled
    print 0 >$S/run-rc; print 0 >$S/gpg-rc
    print 'ActiveState=inactive\nNextElapseUSecRealtime=' >$S/show
}
# run <args...>: the dispatcher; REPLY = its stdout, reply = (status).
run() {
    REPLY=$(zsh -f $REPO/desktop/.local/bin/lockscreen "$@" 2>$S/err)
    reply=($?)
}
has()   { grep -qxF -- "$1" $LOG; }
lines() { grep -c -- "$1" $LOG; }
# The line numbers of two calls, to check their order.
before() {
    local a=$(grep -nF -- "$1" $LOG | head -1 | cut -d: -f1) b=$(grep -nF -- "$2" $LOG | head -1 | cut -d: -f1)
    [[ -n $a && -n $b ]] && (( a < b ))
}
DISABLE="xidlehook-client --socket $S/xidlehook.sock control --action disable"
ENABLE="xidlehook-client --socket $S/xidlehook.sock control --action enable"
CANCEL="systemctl --user stop lockscreen-resume.timer"

# 1. hook-disable with no duration: cancels any timed pause, pauses, no timer.
reset; run hook-disable
(( reply[1] == 0 )) && ok "hook-disable exits 0" || bad "hook-disable status" "${reply[1]} $(<$S/err)"
has $DISABLE && ok "hook-disable pauses the timer" || bad "hook-disable pauses" "$(<$LOG)"
before $CANCEL $DISABLE && ok "hook-disable cancels a timed pause first" || bad "hook-disable cancels first" "$(<$LOG)"
(( $(lines '^systemd-run') == 0 )) && ok "hook-disable starts no resume timer" || bad "no timer" "$(<$LOG)"

# 2. hook-disable 1h: pauses, then a transient timer that runs hook-enable.
reset; run hook-disable 1h
(( reply[1] == 0 )) && ok "hook-disable 1h exits 0" || bad "hook-disable 1h status" "${reply[1]} $(<$S/err)"
call=$(grep '^systemd-run ' $LOG)
[[ $call == "systemd-run --user --quiet --collect --unit=lockscreen-resume --on-active=1h "* ]] \
    && ok "starts lockscreen-resume with --on-active=1h" || bad "the timer's call" "$call"
[[ $call == *" lockscreen hook-enable" ]] && ok "the timer runs lockscreen hook-enable" || bad "the timer's command" "$call"
[[ $call == *"--setenv=PATH=$S/stub:"* && $call == *"--setenv=DOTLIB=$DOTLIB "* ]] \
    && ok "the timer carries PATH and DOTLIB" || bad "the timer's environment" "$call"
before $CANCEL $DISABLE && before $DISABLE 'systemd-run' \
    && ok "cancel, pause, then the timer" || bad "order" "$(<$LOG)"

# 3. A duration that isn't one: refused before anything changes.
reset; run hook-disable soon
(( reply[1] == 2 )) && ok "a bad duration exits 2" || bad "a bad duration's status" "${reply[1]}"
[[ ! -s $LOG ]] && ok "a bad duration changes nothing" || bad "a bad duration ran" "$(<$LOG)"
reset; run hook-disable '1h 30min'
(( reply[1] == 0 )) && grep -q -- '--on-active=1h 30min' $LOG \
    && ok "takes systemd's longer spans (1h 30min)" || bad "1h 30min" "${reply[1]} $(<$LOG)"

# 4. The timer can't start: the pause is undone (no endless pause), status 1.
reset; print 1 >$S/run-rc; run hook-disable 1h
(( reply[1] == 1 )) && ok "a failed timer exits 1" || bad "failed timer status" "${reply[1]}"
before 'systemd-run' $ENABLE && ok "a failed timer resumes the idle lock" || bad "failed timer resumes" "$(<$LOG)"

# 5. The daemon isn't running: hook-disable 1h fails and starts no timer.
reset; rm -f $S/xidlehook.sock; run hook-disable 1h
(( reply[1] != 0 )) && (( $(lines '^systemd-run') == 0 )) \
    && ok "no daemon: fails and starts no timer" || bad "no daemon" "${reply[1]} $(<$LOG)"
zsocket -l $S/xidlehook.sock && exec {REPLY}>&-

# 6. hook-enable: cancels a timed pause, then resumes.
reset; run hook-enable
(( reply[1] == 0 )) && before $CANCEL $ENABLE \
    && ok "hook-enable cancels the timer, then resumes" || bad "hook-enable" "${reply[1]} $(<$LOG)"

# 7. status, plain and --json.
reset; run status
[[ $REPLY == armed ]] && ok "status: armed" || bad "status armed" "$REPLY"
(( $(lines '^systemctl') == 0 )) && ok "plain status asks systemd nothing" || bad "plain status" "$(<$LOG)"
run status --json
[[ $REPLY == '{"state": "armed", "until": null}' ]] && ok "status --json: armed" || bad "json armed" "$REPLY"
: >$S/disabled; run status --json
[[ $REPLY == '{"state": "paused", "until": null}' ]] && ok "status --json: paused, no end" || bad "json paused" "$REPLY"
run status
[[ $REPLY == paused ]] && ok "status: paused" || bad "status paused" "$REPLY"
print 'ActiveState=active\nNextElapseUSecRealtime=@1762272000' >$S/show
strftime -s want '%Y-%m-%dT%H:%M:%S%z' 1762272000
want="${want[1,-3]}:${want[-2,-1]}"
run status --json
[[ $REPLY == "{\"state\": \"paused\", \"until\": \"$want\"}" ]] \
    && ok "status --json: paused until the timer's next run" || bad "json timed" "$REPLY (want $want)"
has 'systemctl --user show lockscreen-resume.timer -p ActiveState -p NextElapseUSecRealtime --timestamp=unix' \
    && ok "reads the timer with systemctl show" || bad "systemctl show" "$(<$LOG)"
python3 -c 'import json, sys, datetime; d = json.loads(sys.argv[1]); datetime.datetime.fromisoformat(d["until"])' "$REPLY" \
    && ok "until parses as ISO 8601 in Python" || bad "until in Python" "$REPLY"
rm -f $S/disabled; run status --json
[[ $REPLY == '{"state": "armed", "until": null}' ]] && ok "armed has no end, even with a timer left" || bad "armed + timer" "$REPLY"
rm -f $S/running; run status --json
[[ $REPLY == '{"state": "not running", "until": null}' ]] && ok "status --json: not running" || bad "json not running" "$REPLY"

# 8. forget-passphrase: gpg-connect-agent under timeout 2, then a notification.
reset; run forget-passphrase
(( reply[1] == 0 )) && ok "forget-passphrase exits 0" || bad "forget status" "${reply[1]} $(<$S/err)"
has 'timeout 2 gpg-connect-agent reloadagent /bye' && has 'gpg-connect-agent reloadagent /bye' \
    && ok "sends reloadagent, bounded by timeout 2" || bad "reloadagent" "$(<$LOG)"
grep -q '^notify-send .*GPG passphrase forgotten' $LOG && before 'gpg-connect-agent' 'notify-send' \
    && ok "then says so in a notification" || bad "notification" "$(<$LOG)"
reset; print 1 >$S/gpg-rc; run forget-passphrase
(( reply[1] == 1 )) && ok "a failing gpg-connect-agent exits 1" || bad "forget failure status" "${reply[1]}"
grep -q '^notify-send .*--urgency=critical.*GPG passphrase not forgotten' $LOG \
    && ok "and the notification says it failed" || bad "failure notification" "$(<$LOG)"
reset; rm -f $S/stub/timeout; run forget-passphrase
(( reply[1] == 0 )) && has 'gpg-connect-agent reloadagent /bye' && (( $(lines '^timeout') == 0 )) \
    && ok "works without timeout" || bad "without timeout" "${reply[1]} $(<$LOG)"
stub timeout 'shift; exec "$@"'

(( fail == 0 )) && print "all passed" || print "$fail failed"
exit $(( fail > 0 ))
