#!/usr/bin/env zsh
# Tests for the coordinator rename (the brain's design record 0018): the
# launcher's homes, aliases and refusals (shell/.config/zsh/.zshrc.d/
# 55-coordinators) and the switchboard's name resolution (dotlib _coord).
#
# Nothing real launches: the homes are a scratch actors dir under ~/.cache,
# claude and the prompt script are stubs that only log (and refuse to run
# from outside the scratch dir), setsid is a stub so _coord can't open a
# window, and every tmux call names its own server, -L coordrename-test, the
# cleanup included. The launcher's tmux tests use throwaway names (test,
# formerly oldtest), never a live coordinator's.
#
#   zsh tests/coordinators.zsh

emulate -L zsh
setopt no_unset

unset TMUX TMUX_PANE TMUX_FORCE COORD_STOP
typeset -r REPO=${0:A:h:h}
typeset -r L=coordrename-test
mkdir -p ~/.cache || exit 1
typeset -r SCRATCH=$(mktemp -d ~/.cache/coordrename-test.XXXXXX)
typeset -r ACTORS=$SCRATCH/actors LOGFILE=$SCRATCH/launched
typeset -r LAUNCHER=$REPO/shell/.config/zsh/.zshrc.d/55-coordinators

mkdir -p $SCRATCH/stub $ACTORS
print -r -- '#!/bin/sh
case "$PWD" in "'$SCRATCH'"/*) ;; *) echo "REAL $PWD" >>"'$LOGFILE'"; exit 99 ;; esac
printf "claude %s | %s\n" "${PWD#'$ACTORS'/}" "$*" >>"'$LOGFILE'"' >$SCRATCH/stub/claude
print -r -- '#!/bin/sh
printf "prompt for %s" "$1"' >$SCRATCH/stub/prompt.sh
# What _coord would reach the desktop through: each only logs.
for c in setsid alacritty bspc xprop polybar-msg notify-send rofi; do
    print -r -- '#!/bin/sh
echo "'$c' $*" >>"'$LOGFILE'"' >$SCRATCH/stub/$c
done
chmod +x $SCRATCH/stub/*

export COORD_ACTORS_DIR=$ACTORS COORD_PROMPT_SCRIPT=$SCRATCH/stub/prompt.sh COORD_TMUX_SOCKET=$L
export COORD_STATE_DIR=$SCRATCH/state COORD_LOCK_DIR=$SCRATCH/lock COORD_LAUNCH_TIMEOUT=0
export DOTLIB=$REPO/shell/.local/share/dotlib
export PATH="$SCRATCH/stub:$PATH"

integer pass=0 fail=0
typeset out err rc
cleanup() {
    command tmux -L $L kill-server 2>/dev/null || true
    rm -rf $SCRATCH
}
trap cleanup EXIT

ok()  { (( ++pass )); print "ok   $1"; }
bad() { (( ++fail )); print "FAIL $1${2:+: $2}"; }

# homes <name>...: exactly these homes exist; the launch log and the test
# server are emptied.
homes() {
    rm -rf $ACTORS; mkdir -p $ACTORS
    local n; for n; do mkdir -p $ACTORS/$n; done
    : >$LOGFILE
    command tmux -L $L kill-server 2>/dev/null || true
    local i; for i in {1..100}; do command tmux -L $L has-session 2>/dev/null || break; sleep 0.02; done
}
session() { command tmux -L $L -f /dev/null new-session -d -s "$1" -x 80 -y 24 "${2:-sleep 100000}"; }

# run <cmd...>: runs the launcher's function in a clean zsh, with the
# throwaway names test and oldtest (its former name) added to the alias map.
# Sets rc, out (stdout) and err (stderr).
typeset -r PRELUDE="source ${(q)LAUNCHER}
_COORDINATOR_ALIASES[oldtest]=test
oldtest-coordinator() { _coordinator-alias oldtest test \"\$@\"; }
test-coordinator() { _coordinator test \"\$@\"; }"
run() {
    rc=0
    out=$(zsh -f -c "$PRELUDE; $*" 2>$SCRATCH/err) || rc=$?
    err=$(<$SCRATCH/err)
}
launched() { [[ -s $LOGFILE ]] && print -r -- "$(<$LOGFILE)"; }

print "== launcher: homes and aliases"
homes
run test-coordinator
[[ $rc != 0 && $err == *'test-coordinator: no home yet'* && -z $(launched) ]] \
    && ok no-home-yet || bad no-home-yet "rc=$rc err=$err launched=$(launched)"

homes oldtest
run oldtest-coordinator --model x
[[ $rc == 0 && -z $err && $(launched) == 'claude oldtest | --permission-mode bypassPermissions --dangerously-skip-permissions --model x prompt for oldtest' ]] \
    && ok alias-old-home-only || bad alias-old-home-only "rc=$rc err=$err launched=$(launched)"

homes test
run oldtest-coordinator
[[ $rc == 0 && $err == 'oldtest-coordinator is now test-coordinator' && $(launched) == 'claude test | '*'prompt for test' ]] \
    && ok alias-new-home || bad alias-new-home "rc=$rc err=$err launched=$(launched)"

homes oldtest
run test-coordinator
[[ $rc != 0 && $err == *'no home yet'* && -z $(launched) ]] \
    && ok new-name-before-move || bad new-name-before-move "rc=$rc err=$err launched=$(launched)"

# The real map: dotfiles is an alias of desktop.
homes dotfiles
run dotfiles-coordinator
[[ $rc == 0 && -z $err && $(launched) == 'claude dotfiles | '*'prompt for dotfiles' ]] \
    && ok real-alias-old || bad real-alias-old "rc=$rc err=$err launched=$(launched)"
homes desktop
run dotfiles-coordinator
[[ $rc == 0 && $err == 'dotfiles-coordinator is now desktop-coordinator' && $(launched) == 'claude desktop | '*'prompt for desktop' ]] \
    && ok real-alias-new || bad real-alias-new "rc=$rc err=$err launched=$(launched)"
homes
run security-coordinator
[[ $rc != 0 && $err == *'security-coordinator: no home yet'* && -z $(launched) ]] \
    && ok security-no-home || bad security-no-home "rc=$rc err=$err"
homes ventures
run ventures-coordinator
[[ $rc == 0 && -z $err && $(launched) == 'claude ventures | '*'prompt for ventures' ]] \
    && ok ventures-launch || bad ventures-launch "rc=$rc err=$err launched=$(launched)"
run 'for n in brain platform personal homelab network-tools media desktop incubator security ventures dotfiles apps ideas metalayerlab template folio; do (( ${+functions[$n-coordinator]} )) || print -n "$n "; done'
[[ -z $out ]] && ok all-functions || bad all-functions "missing: $out"

print "== launcher: refusals (tmux -L $L)"
homes test
session oldtest-coordinator
run test-coordinator
[[ $rc != 0 && $err == *'tmux session oldtest-coordinator is already running'* && -z $(launched) ]] \
    && ok refuse-other-name || bad refuse-other-name "rc=$rc err=$err launched=$(launched)"

homes test
session test-coordinator
run test-coordinator
[[ $rc != 0 && $err == *'tmux session test-coordinator is already running'* && -z $(launched) ]] \
    && ok refuse-own-name-outside || bad refuse-own-name-outside "rc=$rc err=$err"

homes test oldtest
session test-coordinator
run oldtest-coordinator
[[ $rc != 0 && $err == *'test-coordinator is already running'* && -z $(launched) ]] \
    && ok refuse-alias-new-running || bad refuse-alias-new-running "rc=$rc err=$err"

# inside <session> <cmd>: runs <cmd> as a pane of a new session on the test
# server, as the switchboard does (tmux new -A -s <name>-coordinator
# 'zsh -ic ...'), and waits for it. tmux sets TMUX and TMUX_PANE.
inside() {
    local script=$SCRATCH/inside.zsh i
    rm -f $SCRATCH/inside.rc
    {
        print -r -- "export COORD_ACTORS_DIR=${(q)ACTORS} COORD_PROMPT_SCRIPT=${(q)COORD_PROMPT_SCRIPT} COORD_TMUX_SOCKET=$L PATH=${(q)PATH}"
        print -r -- "$PRELUDE"
        print -r -- "$2 2>${(q)SCRATCH}/err; print \$? >${(q)SCRATCH}/inside.rc"
    } >$script
    session "$1" "zsh -f ${(q)script}"
    rc=timeout
    for i in {1..250}; do [[ -s $SCRATCH/inside.rc ]] && { rc=$(<$SCRATCH/inside.rc); break; }; sleep 0.02; done
    err=$(<$SCRATCH/err)
}

homes test
inside test-coordinator test-coordinator
[[ $rc == 0 && $(launched) == 'claude test | '* ]] \
    && ok own-session-not-counted || bad own-session-not-counted "rc=$rc err=$err launched=$(launched)"

homes test
session oldtest-coordinator
inside test-coordinator test-coordinator
[[ $rc != 0 && $err == *'oldtest-coordinator is already running'* && -z $(launched) ]] \
    && ok inside-other-name-counted || bad inside-other-name-counted "rc=$rc err=$err"

homes test
session test-coordinator
inside plain test-coordinator
[[ $rc != 0 && $err == *'test-coordinator is already running'* && -z $(launched) ]] \
    && ok inside-other-session || bad inside-other-session "rc=$rc err=$err"

# A former name started in its own session once the home has moved.
homes test
inside oldtest-coordinator oldtest-coordinator
[[ $rc == 0 && $(launched) == 'claude test | '* ]] \
    && ok alias-own-session || bad alias-own-session "rc=$rc err=$err launched=$(launched)"

print "== switchboard: names (_coord)"
# coord <homes> -- <cmd>: sources _coord in a clean zsh with these homes and
# prints what <cmd> prints. Only name logic runs: no bspwm, rofi or window.
coord() {
    local -a h; while [[ $1 != -- ]]; do h+=($1); shift; done; shift
    homes $h
    coordrun "$@"
}
coordrun() {
    rc=0
    out=$(COORD_NAMES=${COORD_NAMES_TEST:-} zsh -f -c "
        [[ -n \$COORD_NAMES ]] || unset COORD_NAMES
        source \$DOTLIB/_coord || exit 1
        $*" 2>$SCRATCH/err) || rc=$?
    err=$(<$SCRATCH/err)
}
ALLOLD=(brain template folio homelab metalayerlab apps dotfiles ideas)
ALLNEW=(brain platform personal homelab network-tools media desktop incubator security ventures)

coord $ALLOLD -- 'print -r -- $_COORD_NAMES'
[[ $out == "brain template folio homelab metalayerlab apps dotfiles ideas" ]] \
    && ok shown-before-any-move || bad shown-before-any-move "$out"
coord brain homelab incubator template folio metalayerlab apps dotfiles -- 'print -r -- $_COORD_NAMES'
[[ $out == "brain template folio homelab metalayerlab apps dotfiles incubator" ]] \
    && ok shown-mid-migration || bad shown-mid-migration "$out"
coord $ALLNEW -- 'print -r -- $_COORD_NAMES'
[[ $out == "${ALLNEW[*]}" ]] && ok shown-after-all-moves || bad shown-after-all-moves "$out"
coord brain -- 'print -r -- $_COORD_NAMES'
[[ $out == brain ]] && ok security-hidden-no-home || bad security-hidden-no-home "$out"

coord brain dotfiles media -- 'for n in desktop dotfiles apps media brain security bogus; do _coord-resolve $n; print -n "$n=$REPLY "; done'
[[ $out == "desktop=dotfiles dotfiles=dotfiles apps=media media=media brain=brain security=security bogus=bogus " ]] \
    && ok resolve || bad resolve "$out"

coord $ALLNEW -- 'for n in $_COORD_NAMES; do print -n "${_COORD_KEYS[$n]} "; done; print; print -r -- $_COORD_KEYS_HELP'
[[ $out == "b pl pe h n m d i s v "$'\n'"b brain, pl platform, pe personal, h homelab, n network-tools, m media, d desktop, i incubator, s security, v ventures" ]] \
    && ok keys-two-letters || bad keys-two-letters "$out"
coord $ALLOLD -- 'for n in $_COORD_NAMES; do print -n "${_COORD_KEYS[$n]} "; done'
[[ $out == "b t f h m a d i " ]] && ok keys-before-moves || bad keys-before-moves "$out"
coord platform folio -- 'for n in $_COORD_NAMES; do print -n "${_COORD_KEYS[$n]} "; done'
[[ $out == "p f " ]] && ok keys-one-p-shown || bad keys-one-p-shown "$out"
coord $ALLNEW -- 'print -r -- ${_COORD_DESCRIPTIONS[menu]}'
[[ $out == *'pl platform, pe personal'* ]] && ok keys-in-help || bad keys-in-help "$out"

coord $ALLNEW -- 'for n in platform personal network-tools media desktop incubator security ventures dotfiles apps ideas metalayerlab template folio; do [[ -n ${_COORD_ICONS[$n]:-} ]] || print -n "$n "; done
    [[ ${_COORD_ICONS[desktop]} == ${_COORD_ICONS[dotfiles]} && ${_COORD_ICONS[security]} == $'"'"'\U000F0306'"'"' && ${_COORD_ICONS[ventures]} == $'"'"'\U000F1494'"'"' ]] || print -n mismatch'
[[ -z $out ]] && ok icons || bad icons "$out"

coord $ALLNEW -- '_COORD_BAR_COLORS=(dim "#111111"); _coord-menu-row platform off; print -r -- $REPLY'
[[ $out == *'&#10;<u>pl</u>atform&#10;'*'>off</span>' ]] && ok menu-row-key-and-off || bad menu-row-key-and-off "$out"
# rofi's prefix filter at every word start: no state word may start with a key.
# b is left out: busy matches it, but brain is listed first.
coord $ALLNEW -- '_COORD_BAR_COLORS=(); for a in off idle busy waiting; do _coord-menu-row homelab $a 1; print -r -- ${REPLY##*&#10;}; done'
bad_words=()
for w in ${=$(print -r -- $out | sed 's/<[^>]*>/ /g; s/·/ /g')}; do
    for k in pl pe h n m d i s v; do [[ $w == $k* ]] && bad_words+=($w); done
done
(( ! $#bad_words )) && ok state-words-avoid-keys || bad state-words-avoid-keys "$bad_words"

COORD_NAMES_TEST="brain alpha" coord brain -- 'print -r -- $_COORD_LIST / $_COORD_NAMES'
[[ $out == "brain alpha / brain" ]] && ok coord-names-override || bad coord-names-override "$out"

coord dotfiles -- 'coord-launch security; print rc=$?; coord-launch desktop >/dev/null 2>&1; print rc=$?'
[[ $out == rc=1$'\n'rc=0 && $err == *'security: no home yet'* && $(launched) == 'setsid -f alacritty --class coord,dotfiles '*"new-session -A -s dotfiles-coordinator zsh -ic '_coordinator dotfiles; exec zsh -i'" ]] \
    && ok launch-resolves-and-needs-home || bad launch-resolves-and-needs-home "out=$out err=$err launched=$(launched)"

homes desktop
session dotfiles-coordinator
coordrun 'local -A _running _shown; _coord-scan 2>/dev/null; print -r -- ${(k)_running}; _coord-has-session desktop && print has'
[[ $out == "desktop"$'\n'"has" ]] && ok scan-old-session-as-new || bad scan-old-session-as-new "$out"

print "\n$pass passed, $fail failed"
(( fail == 0 ))
