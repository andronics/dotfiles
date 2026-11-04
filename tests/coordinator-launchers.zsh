#!/usr/bin/env zsh
# Tests for the generated coordinator launchers (shell/.config/zsh/.zshrc.d/
# 55-coordinators, the brain's design record 0019 §9 steps 3 and 5): a
# <name>-coordinator function for every name in meta's copy of the registry,
# each running `meta <name> launch --attach` with its arguments; each former
# name an announced alias until its date; one meta call when there is no copy;
# _coordinator running the brain's launch script; and no coordinator's name
# written in the file outside comments.
#
# Nothing real runs: meta is a stub on PATH that only logs its arguments, the
# registry copy is a scratch file (COORD_REGISTRY_FILE), and each case runs in
# a clean `zsh -f`. No claude, no live coordinator; the one tmux check uses
# its own server, -L coordinator-launchers-test, the cleanup included.
#
#   zsh tests/coordinator-launchers.zsh

emulate -L zsh
setopt no_unset extended_glob

unset TMUX TMUX_PANE COORDINATOR CLAUDECODE COORD_TODAY COORD_LAUNCH_SCRIPT
typeset -r REPO=${0:A:h:h}
typeset -r LAUNCHER=$REPO/shell/.config/zsh/.zshrc.d/55-coordinators
mkdir -p ~/.cache || exit 1
typeset -r S=$(mktemp -d ~/.cache/coordinator-launchers-test.XXXXXX) || exit 1
typeset -r L=coordinator-launchers-test
cleanup() {
    command tmux -L $L kill-server 2>/dev/null || true
    rm -rf -- "${S:?}"
}
trap cleanup EXIT
typeset -r LOG=$S/meta.log REG=$S/coordinators.json

mkdir -p $S/stub
# meta: logs "meta <args>"; answers `<registry> coordinators --names` from
# $S/names (and writes the copy from $S/copy, as the real one does).
print -r -- '#!/bin/sh
echo "meta $*" >>"'$LOG'"
printf "%s\n" "$@" >"'$S'/args"
if [ "$2 $3" = "coordinators --names" ]; then
    [ -f "'$S'/copy" ] && cp "'$S'/copy" "'$REG'"
    cat "'$S'/names"
fi
exit 0' >$S/stub/meta
chmod +x $S/stub/meta
export PATH="$S/stub:$PATH" COORD_REGISTRY_FILE=$REG TOOL_JOURNAL=off

integer pass=0 fail=0
typeset out err rc
ok()  { (( ++pass )); print "ok   $1"; }
bad() { (( ++fail )); print "FAIL $1${2:+: $2}"; }

# copy <entries...>: the registry copy as meta writes it (one line,
# ensure_ascii off), each entry "name old1,old2 until".
copy() {
    local e name olds until sep= body=
    for e; do
        name=${e%% *} olds=${${e#* }% *} until=${e##* }
        [[ $olds == - ]] && olds=
        body+="$sep{\"name\": \"$name\", \"slug\": \"$name-coordinator\", \"tmux_session\": \"$name-coordinator\", \"home\": \"/pool/x/$name\", \"note\": \"🧭 $name Coordinator\", \"old_names\": [${olds:+\"${olds//,/\", \"}\"}], \"old_names_until\": \"$until\", \"menu_order\": 10, \"repos\": [\"o/$name-repo\"]}"
        sep=", "
    done
    print -r -- "{\"source\": \"/vault\", \"generated\": \"2026-11-04T05:01:33+00:00\", \"coordinators\": [$body]}"
}

# run <cmd>: sources the launcher in a clean zsh, then runs <cmd>.
run() {
    rc=0; : >$LOG
    out=$(zsh -f -c "source ${(q)LAUNCHER}; $*" 2>$S/err) || rc=$?
    err=$(<$S/err)
}
logged() { [[ -s $LOG ]] && print -r -- "$(<$LOG)"; }

print "== generated from the registry's copy"
copy "alpha - 2026-12-04" "beta-two old1,old2 2026-12-04" "gamma gone 2026-01-01" >$REG
run 'print -l ${(ok)functions[(I)*-coordinator]}'
[[ $out == "alpha-coordinator"$'\n'"beta-two-coordinator"$'\n'"gamma-coordinator"$'\n'"old1-coordinator"$'\n'"old2-coordinator" ]] \
    && ok every-name-and-live-old-name || bad every-name-and-live-old-name "$out"
[[ -z $(logged) ]] && ok no-meta-call-at-start || bad no-meta-call-at-start "$(logged)"
run 'alpha-coordinator'
[[ $rc == 0 && -z $err && $(logged) == 'meta alpha launch --attach' ]] && ok launch-attach || bad launch-attach "rc=$rc err=$err $(logged)"
run 'beta-two-coordinator -- --model "x y"; print -r -- $?'
[[ $(logged) == 'meta beta-two launch --attach -- --model x y' && $out == 0 ]] && ok arguments-passed || bad arguments-passed "$(logged)"
run 'beta-two-coordinator -- "a b" "" c'
[[ $(<$S/args) == "beta-two"$'\n'"launch"$'\n'"--attach"$'\n'"--"$'\n'"a b"$'\n'$'\n'"c" ]] \
    && ok arguments-kept-whole || bad arguments-kept-whole "$(<$S/args)"
run 'old2-coordinator --x'
[[ $err == 'old2-coordinator is now beta-two-coordinator' && $(logged) == 'meta beta-two launch --attach --x' ]] \
    && ok old-name-announced || bad old-name-announced "err=$err $(logged)"
run '(( ${+functions[gone-coordinator]} )) && print defined'
[[ -z $out ]] && ok expired-alias-dropped || bad expired-alias-dropped "$out"
COORD_TODAY=2025-12-31 run '(( ${+functions[gone-coordinator]} )) && print defined'
[[ $out == defined ]] && ok alias-kept-until-its-date || bad alias-kept-until-its-date "$out"
COORD_TODAY=2026-12-04 run '(( ${+functions[old1-coordinator]} )) && print defined'
[[ $out == defined ]] && ok alias-kept-on-its-date || bad alias-kept-on-its-date "$out"
COORD_TODAY=2026-12-05 run '(( ${+functions[old1-coordinator]} )) && print defined'
[[ -z $out ]] && ok alias-gone-after-its-date || bad alias-gone-after-its-date "$out"
run 'print -r -- ${+functions[_coordinator-registry]}'
[[ $out == 0 ]] && ok helper-removed || bad helper-removed "$out"

# A current name is never shadowed by another's old name; odd names define nothing.
copy "alpha beta 2999-01-01" "beta - 2999-01-01" "Bad;name - 2999-01-01" >$REG
run 'beta-coordinator; print -l ${(ok)functions[(I)*-coordinator]}'
[[ -z $err && $(logged) == 'meta beta launch --attach' && $out == "alpha-coordinator"$'\n'"beta-coordinator" ]] \
    && ok current-name-wins-and-odd-names-skipped || bad current-name-wins-and-odd-names-skipped "err=$err out=$out"

# The live copy's shape (dense JSON, no spaces) parses the same.
copy "alpha old1 2999-01-01" | sed 's/": /":/g; s/, /,/g' >$REG
run 'print -l ${(ok)functions[(I)*-coordinator]}'
[[ $out == "alpha-coordinator"$'\n'"old1-coordinator" ]] && ok dense-json || bad dense-json "$out"

print "== no copy yet: one meta call"
rm -f $REG $S/copy
print -l alpha beta 'not a name' >$S/names
run 'print -l ${(ok)functions[(I)*-coordinator]}'
[[ $out == "alpha-coordinator"$'\n'"beta-coordinator" && $(logged) == 'meta brain coordinators --names' ]] \
    && ok fallback-names || bad fallback-names "out=$out $(logged)"
copy "alpha old1 2999-01-01" "beta - 2999-01-01" >$S/copy
run 'print -l ${(ok)functions[(I)*-coordinator]}'
[[ $out == "alpha-coordinator"$'\n'"beta-coordinator"$'\n'"old1-coordinator" && $(logged) == 'meta brain coordinators --names' ]] \
    && ok fallback-reads-the-copy-meta-wrote || bad fallback-reads-the-copy-meta-wrote "out=$out $(logged)"
rm -f $REG $S/copy
out=$(PATH=/usr/bin:/bin zsh -f -c "source ${(q)LAUNCHER}; print -rn -- \${(ok)functions[(I)*-coordinator]}; print rc=\$?" 2>&1)
[[ $out == rc=0 ]] && ok no-meta-no-copy-defines-nothing || bad no-meta-no-copy-defines-nothing "$out"

print "== _coordinator: the brain's launch script"
# A stub tree like the brain's: bin/meta, and tools/coordinator-launch.sh next to it.
mkdir -p $S/tree/bin $S/tree/tools
cp $S/stub/meta $S/tree/bin/meta
print -r -- '#!/bin/sh
echo "launch-script $*" >>"'$LOG'"' >$S/tree/tools/coordinator-launch.sh
chmod +x $S/tree/tools/coordinator-launch.sh
copy "alpha - 2999-01-01" >$REG
rc=0; : >$LOG
PATH=$S/tree/bin:$PATH zsh -f -c "source ${(q)LAUNCHER}; _coordinator alpha --model x" 2>$S/err || rc=$?
[[ $rc == 0 && $(logged) == 'launch-script alpha --model x' ]] && ok finds-script-next-to-meta || bad finds-script-next-to-meta "rc=$rc $(logged) $(<$S/err)"
COORD_LAUNCH_SCRIPT=$S/none run '_coordinator alpha'
[[ $rc == 2 && $err == *'no launch script at '$S/none* ]] && ok missing-script-says-so || bad missing-script-says-so "rc=$rc err=$err"
# coord's path doesn't go through meta: a session under the other name refuses.
copy "beta old1 2999-01-01" >$REG
command tmux -L $L -f /dev/null new-session -d -s old1-coordinator 'sleep 100000'
COORD_TMUX_SOCKET=$L COORD_LAUNCH_SCRIPT=$S/tree/tools/coordinator-launch.sh run '_coordinator beta'
[[ $rc == 1 && $err == *'tmux session old1-coordinator is already running'* && -z $(logged) ]] \
    && ok other-name-session-refuses || bad other-name-session-refuses "rc=$rc err=$err $(logged)"
COORD_TMUX_SOCKET=$L COORD_LAUNCH_SCRIPT=$S/tree/tools/coordinator-launch.sh run '_coordinator old1'
[[ $rc == 0 && $(logged) == 'launch-script old1' ]] && ok own-session-not-counted || bad own-session-not-counted "rc=$rc err=$err $(logged)"
command tmux -L $L kill-server 2>/dev/null
command tmux -L $L -f /dev/null new-session -d -s beta-coordinator 'sleep 100000'
COORD_TMUX_SOCKET=$L COORD_LAUNCH_SCRIPT=$S/tree/tools/coordinator-launch.sh run '_coordinator old1'
[[ $rc == 1 && $err == *'tmux session beta-coordinator is already running'* ]] && ok new-name-session-refuses-old || bad new-name-session-refuses-old "rc=$rc err=$err"
command tmux -L $L kill-server 2>/dev/null
copy "alpha - 2999-01-01" >$REG
# End to end with the brain's real script, if this machine has it: COORDINATOR
# is set (record 0017) and claude runs in the home. Stubs only, scratch homes.
typeset -r REAL=/mnt/brain/tools/coordinator-launch.sh
if [[ -x $REAL ]]; then
    mkdir -p $S/actors/alpha
    print -r -- '#!/bin/sh
printf "claude %s COORDINATOR=%s | %s\n" "${PWD##*/}" "$COORDINATOR" "$*" >>"'$LOG'"' >$S/stub/claude
    print -r -- '#!/bin/sh
printf "prompt for %s" "$1"' >$S/stub/prompt.sh
    chmod +x $S/stub/claude $S/stub/prompt.sh
    ACTORS_HOME=$S/actors COORD_PROMPT_SCRIPT=$S/stub/prompt.sh COORD_CLAUDE=$S/stub/claude COORD_LAUNCH_SCRIPT=$REAL \
        run '_coordinator alpha --model x'
    [[ $rc == 0 && $(logged) == 'claude alpha COORDINATOR=alpha-coordinator | --permission-mode bypassPermissions --dangerously-skip-permissions --model x prompt for alpha' ]] \
        && ok real-script-exports-coordinator || bad real-script-exports-coordinator "rc=$rc err=$err $(logged)"
else
    print "skip real-script-exports-coordinator: no $REAL"
fi

print "== no coordinator's name in the file (record 0019 §9 step 5)"
# names <file>: REPLY = "<line>: <text>" for each use of a name in $NAMES in
# <file> outside comments (a line whose first non-blank is #, and the rest of
# a line after a blank and a #), the registry's address `meta brain
# coordinators` allowed. A name counts as a word: no letter, digit or _ on
# either side (a hyphen is a boundary, so brain-coordinator counts).
names_in() {
    local line n=0 word
    local -a found
    while IFS= read -r line || [[ -n $line ]]; do
        (( ++n ))
        [[ $line == [[:space:]]#\#* ]] && continue
        line=${line%%[[:space:]]\#*}
        line=${line//meta brain coordinators/}
        for word in $NAMES; do
            [[ $line == (|*[^a-z0-9_])$word(|[^a-z0-9_]*) ]] && found+=("$n: $word: ${line##[[:space:]]#}")
        done
    done <$1
    REPLY=${(F)found}
}
# Today's names and former names, and any in this machine's copy of the registry.
NAMES=(brain platform personal homelab network-tools media desktop incubator security ventures
       dotfiles apps ideas metalayerlab template folio)
live=${XDG_CACHE_HOME:-$HOME/.cache}/meta/coordinators.json
if [[ -r $live ]]; then
    NAMES+=(${(M)${(f)"$(COORD_REGISTRY_FILE=$live COORD_TODAY=0000-01-01 zsh -f -c "source ${(q)LAUNCHER}; print -l \${(k)functions[(I)*-coordinator]%-coordinator}" 2>/dev/null)"}:#[a-z0-9][a-z0-9-]#})
fi
NAMES=(${(u)NAMES})

# The scan, on planted files.
print -rl -- 'x() { meta desktop launch; }' '  brain-coordinator() { :; }' >$S/planted
print -rl -- '# desktop in a comment' 'echo hi  # brain trailing' 'meta brain coordinators --names' \
    'mediax xbrain desktops _personal' >$S/clean
names_in $S/planted; planted=$REPLY
names_in $S/clean
[[ $planted == "1: desktop: x() { meta desktop launch; }"$'\n'"2: brain: brain-coordinator() { :; }" && -z $REPLY ]] \
    && ok "the scan catches planted names and skips comments and the registry's address" \
    || bad "the scan on planted files" "planted=$planted clean=$REPLY"

names_in $LAUNCHER
[[ -z $REPLY ]] && ok "no coordinator name in 55-coordinators outside comments (${#NAMES} names)" \
    || bad "a coordinator name in 55-coordinators" $'\n'"$REPLY"

print "\n$pass passed, $fail failed"
(( fail == 0 ))
