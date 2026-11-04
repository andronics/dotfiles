#!/usr/bin/env zsh
# Tests for dotlib's journal output (the brain's design record 0017): _log
# writes warnings and errors under the tool's own name, never debug or info
# lines and never arguments; _dispatcher writes one run entry per run (and
# one line in the run store), none under TOOL_STATS=skip. (COORDINATOR is
# exported by the brain's launch script now, record 0019 §9; see
# tests/coordinator-launchers.zsh.)
#
# Nothing reaches the real journal: logger is a stub on PATH that appends
# what it is given to a file, and the run store and rate-limit stamps are in
# the scratch dir. The tools under test are a throwaway dispatcher (jt) and
# `coord` asked for an unknown command, in a scratch actors dir; its tmux
# calls name their own server (-L dotlib-journal-test), the cleanup included.
#
#   zsh tests/dotlib-journal.zsh

emulate -L zsh
setopt no_unset

unset TMUX TMUX_PANE TOOL_STATS TOOL_JOURNAL COORDINATOR CLAUDECODE LOG_SYSTEMD_TAG LOG_LEVEL
typeset -r REPO=${0:A:h:h}
typeset -r L=dotlib-journal-test
mkdir -p ~/.cache || exit 1
typeset -r S=$(mktemp -d ~/.cache/dotlib-journal-test.XXXXXX)
typeset -r JLOG=$S/journal RUNS=$S/runs ACTORS=$S/actors

mkdir -p $S/stub $S/bin $ACTORS
# logger: one "@@ entry <args>" line, then the fields it was given on stdin.
print -r -- '#!/bin/sh
echo "@@ entry $*" >>"'$JLOG'"
cat >>"'$JLOG'"' >$S/stub/logger
chmod +x $S/stub/*

# jt: a throwaway dispatcher over a module of test commands.
print -r -- 'jt-ok()     { log-info "all fine"; log-success "done"; print ran-ok; }
jt-warn()   { log-warning "disk nearly full: $*"; }
jt-secret() { log-error "login failed password=hunter2xyz token: ghp_abcdefghijklmnop12345 url https://bob:s3cret@example.com/x"; }
jt-debug()  { log-debug "debugging with $*"; }
jt-fail()   { return 5; }
jt-answer() { return 3; }
jt-exit()   { ( exit 2 ); x=$(exit 3); exit 4; }
jt-both()   { log-warning "first"; log-error "second"; return 0; }' >$S/bin/_jt
print -r -- '#!/usr/bin/env zsh
set -e
source "${DOTLIB}/_dispatcher" || exit 1
source '$S'/bin/_jt
dispatcher-init "jt" --route=function --results=3 --description="journal test"
dispatcher-execute "$@"' >$S/bin/jt
# notdispatcher: a plain script that sources _log.
print -r -- '#!/usr/bin/env zsh
source "${DOTLIB}/_log"
log-error "plain script failed"' >$S/bin/notdispatcher
chmod +x $S/bin/*

export DOTLIB=$REPO/shell/.local/share/dotlib
export PATH="$S/stub:$PATH"
export TOOL_RUNS_DIR=$RUNS TOOL_JOURNAL_STAMPS=$S/stamps
export COORD_ACTORS_DIR=$ACTORS COORD_TMUX_SOCKET=$L
export COORD_STATE_DIR=$S/state COORD_LOCK_DIR=$S/lock COORD_LAUNCH_TIMEOUT=0

integer pass=0 fail=0
typeset out err rc
cleanup() {
    command tmux -L $L kill-server 2>/dev/null || true
    rm -rf -- "${S:?}"
}
trap cleanup EXIT

ok()  { (( ++pass )); print "ok   $1"; }
bad() { (( ++fail )); print "FAIL $1${2:+: $2}"; }

# fresh: empties the journal stub's file, the run store and the stamps.
fresh() { : >$JLOG; rm -rf -- "${RUNS:?}" "$S/stamps"; }
# jt <args>: runs the dispatcher (zsh -f, so ~/.zshenv can't repoint DOTLIB).
jt() { rc=0; out=$(zsh -f $S/bin/jt "$@" 2>$S/err) || rc=$?; err=$(<$S/err); }
# entries [pattern]: how many journal entries (field lines matching the
# glob pattern; quote [ and ] as \[ \]).
entries() {
    local -a e=("${(@f)$(<$JLOG)}")
    if (( $# )); then print ${#${(M)e:#$~1}}; else print ${#${(M)e:#@@ entry*}}; fi
}
journal() { print -r -- "$(<$JLOG)"; }
runlines() { local f=($RUNS/*.jsonl(N)); (( ${#f} )) && cat $f || true; }

print "== warnings and errors under the tool's name"
fresh; jt warn somedisk
[[ $(entries) == 2 && $(entries SYSLOG_IDENTIFIER=jt) == 2 && $(entries TOOL_EVENT=warning) == 1 \
    && $(entries PRIORITY=4) == 1 && $(entries TOOL_COMMAND=warn) == 2 && $(entries TOOL_OWNER=desktop-coordinator) == 2 \
    && $(entries 'MESSAGE=disk nearly full: \[arg\]') == 1 && $(entries TOOL_EVENT=run) == 1 \
    && $(entries 'SYSLOG_IDENTIFIER=log') == 0 && $(entries '@@ entry --journald') == 2 ]] \
    && ok warning-under-tool-name || bad warning-under-tool-name "$(journal)"
[[ $(journal) != *somedisk* && $(runlines) != *somedisk* ]] && ok warning-arg-scrubbed || bad warning-arg-scrubbed "$(journal)"
# The error and run entries of one run share TOOL_RUN.
runs=(${(u)${(M)${(f)"$(<$JLOG)"}:#TOOL_RUN=*}})
[[ ${#runs} == 1 && $runs[1] == TOOL_RUN=[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f] ]] \
    && ok one-run-id || bad one-run-id "${runs[*]}"

fresh; rc=0; zsh -f $REPO/desktop/.local/bin/coord nosuchcommand 2>/dev/null >/dev/null || rc=$?
[[ $rc != 0 && $(entries SYSLOG_IDENTIFIER=coord) == 2 && $(entries TOOL_EVENT=error) == 1 \
    && $(entries 'MESSAGE=Unknown command: \[arg\]') == 1 && $(journal) != *nosuchcommand* && $(entries 'TOOL_COMMAND=*') == 0 ]] \
    && ok real-dispatcher-error-as-coord || bad real-dispatcher-error-as-coord "rc=$rc $(journal)"

fresh; rc=0; zsh -f $S/bin/notdispatcher 2>/dev/null || rc=$?
[[ $(entries SYSLOG_IDENTIFIER=notdispatcher) == 1 && $(entries TOOL_EVENT=error) == 1 && $(entries TOOL_EVENT=run) == 0 ]] \
    && ok plain-script-under-own-name || bad plain-script-under-own-name "$(journal)"

print "== redaction"
fresh; jt secret
j=$(journal)
[[ $j != *hunter2xyz* && $j != *ghp_abcdef* && $j != *s3cret* && $j == *'password=[redacted]'* \
    && $j == *'token: [redacted]'* && $j == *'https://[redacted]@example.com'* && $(entries PRIORITY=3) == 1 ]] \
    && ok secrets-redacted || bad secrets-redacted "$j"

print "== debug and info never reach the journal"
fresh; LOG_LEVEL=debug jt debug topsecretarg
[[ $err == *'Calling function: jt-debug topsecretarg'* && $err == *'debugging with topsecretarg'* ]] \
    && ok debug-printed || bad debug-printed "err=$err"
[[ $(entries) == 1 && $(entries TOOL_EVENT=run) == 1 && $(journal) != *topsecretarg* && $(journal) != *Calling* ]] \
    && ok debug-not-journalled || bad debug-not-journalled "$(journal)"
fresh; jt ok
[[ $out == ran-ok && $(entries) == 1 && $(entries TOOL_EVENT=run) == 1 && $(journal) != *'all fine'* && $(journal) != *done* ]] \
    && ok info-not-journalled || bad info-not-journalled "out=$out $(journal)"

print "== one run entry per run, no arguments"
fresh; jt ok verysecretvalue --token=flagvalue123 --level=9
j=$(journal); r=$(runlines)
[[ $(entries) == 1 && $(entries TOOL_EVENT=run) == 1 && $(entries EXIT_CODE=0) == 1 && $(entries OUTCOME=ok) == 1 \
    && $(entries PRIORITY=6) == 1 && $(entries TOOL_COMMAND=ok) == 1 && $(entries 'DURATION_MS=*') == 1 \
    && $(entries 'TOOL_VERSION=*') == 1 && $(entries 'TOOL_ERRORS=0') == 1 && $(entries 'MESSAGE=jt ok: exit 0 \(ok\), <-> ms') == 1 ]] \
    && ok run-entry-fields || bad run-entry-fields "$j"
[[ $j != *verysecretvalue* && $j != *flagvalue123* && $r != *verysecretvalue* && $r != *flagvalue123* ]] \
    && ok run-entry-no-args || bad run-entry-no-args "$j / $r"
rl=(${(f)r})
[[ ${#rl} == 1 && $r =~ '^\{"ts":"20[0-9-]{8}T[0-9:]{8}\.[0-9]{3}Z","tool":"jt","command":"ok","exit":0,"outcome":"ok","duration_ms":[0-9]+,"actor":"system","owner":"desktop-coordinator","version":"[0-9a-f]{0,7}","run":"[0-9a-f]{8}"\}$' ]] \
    && jq -e '.tool == "jt"' <<<"$r" >/dev/null 2>&1 \
    && ok run-store-line || bad run-store-line "$r"
f=($RUNS/*.jsonl(N))
[[ ${#f} == 1 && $(stat -c %a $f[1]) == 600 && $(stat -c %a $RUNS) == 700 ]] && ok run-store-modes || bad run-store-modes "$(ls -la $RUNS)"

fresh; jt fail
[[ $rc == 5 && $(entries TOOL_EVENT=run) == 1 && $(entries OUTCOME=fail) == 1 && $(entries PRIORITY=3) == 1 ]] \
    && ok fail-outcome || bad fail-outcome "rc=$rc $(journal)"
fresh; jt answer
[[ $rc == 3 && $(entries OUTCOME=result) == 1 && $(entries PRIORITY=6) == 1 ]] && ok declared-result || bad declared-result "rc=$rc $(journal)"
fresh; jt exit
[[ $rc == 4 && $(entries TOOL_EVENT=run) == 1 && $(entries EXIT_CODE=4) == 1 && $(entries OUTCOME=fail) == 1 ]] \
    && ok exit-inside-command || bad exit-inside-command "rc=$rc $(journal)"
fresh; jt both
[[ $(entries TOOL_EVENT=run) == 1 && $(entries TOOL_ERRORS=2) == 1 && $(entries) == 3 ]] && ok errors-counted || bad errors-counted "$(journal)"
fresh; jt ok --help
[[ $out != *ran-ok* && $(entries TOOL_EVENT=run) == 1 && $(entries TOOL_COMMAND=help) == 1 ]] \
    && ok help-runs-nothing || bad help-runs-nothing "out=$out $(journal)"
fresh; jt nosuch
[[ $rc == 1 && $(entries TOOL_EVENT=run) == 1 && $(entries 'TOOL_COMMAND=*') == 0 ]] && ok unknown-command-unnamed || bad unknown-command-unnamed "$(journal)"

print "== rate limit"
fresh; jt warn x; jt warn x
[[ $(entries TOOL_EVENT=warning) == 1 && $(entries TOOL_EVENT=run) == 2 ]] && ok same-warning-once-a-minute || bad same-warning-once-a-minute "$(journal)"

print "== TOOL_STATS=skip and TOOL_JOURNAL=off"
fresh; TOOL_STATS=skip jt ok
[[ $out == ran-ok && $(entries) == 0 && -z $(runlines) ]] && ok skip-no-run-entry || bad skip-no-run-entry "$(journal) / $(runlines)"
fresh; TOOL_STATS=skip jt warn y
[[ $(entries) == 1 && $(entries TOOL_EVENT=warning) == 1 && -z $(runlines) ]] && ok skip-still-logs-warnings || bad skip-still-logs-warnings "$(journal)"
fresh; TOOL_JOURNAL=off jt both
[[ $(entries) == 0 && -z $(runlines) && $err == *first*second* ]] && ok journal-off || bad journal-off "$(journal)"

print "== the calling actor"
fresh; COORDINATOR=desktop-coordinator jt ok
[[ $(entries TOOL_ACTOR=desktop-coordinator) == 1 && $(runlines) == *'"actor":"desktop-coordinator"'* ]] && ok actor-coordinator || bad actor-coordinator "$(journal)"
fresh; COORDINATOR='Bad Name;x' jt ok
[[ $(entries TOOL_ACTOR=unknown) == 1 ]] && ok actor-bad-slug || bad actor-bad-slug "$(journal)"
fresh; CLAUDECODE=1 jt ok
[[ $(entries TOOL_ACTOR=claude) == 1 ]] && ok actor-claude || bad actor-claude "$(journal)"
fresh; jt ok </dev/null
[[ $(entries TOOL_ACTOR=system) == 1 ]] && ok actor-system || bad actor-system "$(journal)"

print "\n$pass passed, $fail failed"
(( fail == 0 ))
