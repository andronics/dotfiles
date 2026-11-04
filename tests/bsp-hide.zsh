#!/usr/bin/env zsh
# `bsp hide` / `bsp unhide` (dotlib _bsp), which the screen-lock hooks and the
# sxhkd hide chord run: hide records exactly which nodes it hid, and unhide
# restores only those, so windows that were hidden on purpose before (the
# coordinator windows, empty receptacles) stay hidden (dotfiles issue #84).
# `bsp unhide --all` still reveals every hidden node on the focused desktop.
#
# Runs the real `bsp` wrapper (zsh -f, so no rc files) against a fake bspc
# that keeps node state in a scratch file, with a scratch XDG_RUNTIME_DIR, so
# the real bspwm, polybar and the live $XDG_RUNTIME_DIR/bsp are never touched.
# pgrep and barctl are stubs too: barctl only logs.
#
#   zsh tests/bsp-hide.zsh

emulate -L zsh
setopt no_unset

typeset -r REPO=${0:A:h:h}
mkdir -p ~/.cache || exit 1
typeset -r S=$(mktemp -d ~/.cache/bsp-hide-test.XXXXXX) || exit 1
trap 'rm -rf -- "${S:?}"' EXIT

typeset -r STATE=$S/nodes LOG=$S/calls RUN=$S/run
typeset -r RECORD=$RUN/bsp/hidden
mkdir -p $S/stub $RUN

# The fake bspc. $STATE holds one node per line, "<id> <shown|hidden>"; every
# node is a leaf on the focused desktop. It answers only what _bsp asks.
print -r -- '#!/bin/sh
st="'$STATE'"
echo "bspc $*" >>"'$LOG'"
if [ "$1" = query ] && [ "$2" = -N ] && [ "$3" = -n ]; then
    case "$4" in
        .leaf)         awk "{print \$1}" "$st" ;;
        .hidden)       awk "\$2==\"hidden\"{print \$1}" "$st" ;;
        .leaf.!hidden) awk "\$2==\"shown\"{print \$1}" "$st" ;;
        0x*)           grep -q "^$4 " "$st" && echo "$4" || exit 1 ;;
        *)             exit 1 ;;
    esac
    exit 0
fi
if [ "$1" = node ] && [ "$3" = -g ]; then
    grep -q "^$2 " "$st" || exit 1
    case "$4" in hidden=on) v=hidden ;; hidden=off) v=shown ;; *) exit 1 ;; esac
    awk -v id="$2" -v v="$v" "\$1==id{\$2=v}1" "$st" >"$st.new" && mv "$st.new" "$st"
    exit 0
fi
exit 1' >$S/stub/bspc
print -r -- '#!/bin/sh
exit 0' >$S/stub/pgrep
print -r -- '#!/bin/sh
echo "barctl $*" >>"'$LOG'"' >$S/stub/barctl
chmod +x $S/stub/*

export DOTLIB=$REPO/shell/.local/share/dotlib XDG_RUNTIME_DIR=$RUN TOOL_JOURNAL=off
export PATH="$S/stub:/usr/bin:/bin"

integer fail=0
ok()  { print "ok   $1"; }
bad() { (( ++fail )); print "FAIL $1${2:+: $2}"; }

# state <id>=<shown|hidden>...: resets the desktop, the log and the record.
state() {
    local n
    : >$STATE; : >$LOG
    rm -rf -- $RUN/bsp
    for n in "$@"; do print -r -- "${n%%=*} ${n#*=}" >>$STATE; done
}
# bsp <args>: runs the wrapper; output to $S/out, REPLY its status.
bsp() { zsh -f $REPO/desktop/.local/bin/bsp "$@" >$S/out 2>&1; REPLY=$?; }
# shown: the shown ids, space-separated and sorted.
shown() { print -r -- ${(o)$(awk '$2=="shown"{print $1}' $STATE)}; }
record() { [[ -f $RECORD ]] && print -r -- ${(o)$(<$RECORD)} || print -r -- '(none)'; }
# lines: how many lines the record has (0 when there is none).
lines() { [[ -f $RECORD ]] && print -r -- ${#${(f)"$(<$RECORD)"}} || print 0; }

typeset -r A=0x01 B=0x02 C=0x03 R=0x04 D=0x05

# 1. Windows A, B shown; coordinator C and empty receptacle R hidden.
state $A=shown $B=shown $C=hidden $R=hidden
bsp hide
(( REPLY == 0 )) && ok "hide returns 0" || bad "hide returns 0" "status $REPLY; $(<$S/out)"
[[ -z $(shown) ]] && ok "hide: all hidden" || bad "hide: all hidden" "shown: $(shown)"
[[ $(record) == "$A $B" ]] && ok "hide: record holds A and B only" || bad "hide: record holds A and B only" "$(record)"
grep -q "node $C -g\|node $R -g" $LOG \
    && bad "hide: leaves already-hidden C and R alone" "$(<$LOG)" || ok "hide: leaves already-hidden C and R alone"
grep -qx 'barctl hide' $LOG && ok "hide: bar hidden" || bad "hide: bar hidden" "$(<$LOG)"
bsp unhide
(( REPLY == 0 )) && ok "unhide returns 0" || bad "unhide returns 0" "status $REPLY; $(<$S/out)"
[[ $(shown) == "$A $B" ]] && ok "unhide: A and B shown, C and R still hidden" \
    || bad "unhide: A and B shown, C and R still hidden" "shown: $(shown)"
[[ ! -e $RECORD ]] && ok "unhide: no record left" || bad "unhide: no record left" "$(record)"
grep -qx 'barctl unhide' $LOG && ok "unhide: bar shown" || bad "unhide: bar shown" "$(<$LOG)"

# 2. Hide twice (a window D opened in between), then unhide once.
state $A=shown $B=shown $C=hidden $R=hidden
bsp hide
print -r -- "$D shown" >>$STATE
bsp hide
[[ $(record) == "$A $B $D" ]] && ok "hide twice: record keeps A, B and adds D" \
    || bad "hide twice: record keeps A, B and adds D" "$(record)"
(( $(lines) == 3 )) && ok "hide twice: no duplicates" || bad "hide twice: no duplicates" "$(record)"
bsp hide
(( $(lines) == 3 )) && ok "hide thrice: record unchanged" || bad "hide thrice: record unchanged" "$(record)"
bsp unhide
[[ $(shown) == "$A $B $D" ]] && ok "hide twice, unhide: A, B, D shown, C and R hidden" \
    || bad "hide twice, unhide: A, B, D shown, C and R hidden" "shown: $(shown)"

# 3. A recorded node that has gone is skipped.
state $A=shown $B=shown $C=hidden
bsp hide
grep -v "^$B " $STATE >$STATE.new; mv $STATE.new $STATE
: >$LOG
bsp unhide
(( REPLY == 0 )) && ok "gone node: unhide returns 0" || bad "gone node: unhide returns 0" "status $REPLY; $(<$S/out)"
[[ $(shown) == $A ]] && ok "gone node: A shown, C hidden" || bad "gone node: A shown, C hidden" "shown: $(shown)"
grep -q "node $B -g" $LOG && bad "gone node: B not touched" "$(<$LOG)" || ok "gone node: B not touched"
[[ ! -e $RECORD ]] && ok "gone node: no record left" || bad "gone node: no record left"

# 4. Unhide with no record changes nothing.
state $A=hidden $C=hidden $R=hidden
bsp unhide
(( REPLY == 0 )) && ok "no record: unhide returns 0" || bad "no record: unhide returns 0" "status $REPLY"
[[ -z $(shown) ]] && ok "no record: nothing unhidden" || bad "no record: nothing unhidden" "shown: $(shown)"
grep -qi 'no record' $S/out && ok "no record: says so" || bad "no record: says so" "$(<$S/out)"

# 5. --all reveals every hidden node on the focused desktop, and drops the record.
state $A=shown $C=hidden $R=hidden
bsp hide
bsp unhide --all
(( REPLY == 0 )) && ok "--all returns 0" || bad "--all returns 0" "status $REPLY; $(<$S/out)"
[[ $(shown) == "$A $C $R" ]] && ok "--all: everything shown" || bad "--all: everything shown" "shown: $(shown)"
[[ ! -e $RECORD ]] && ok "--all: no record left" || bad "--all: no record left" "$(record)"
bsp help
grep -q 'unhide --all' $S/out && ok "help mentions unhide --all" || bad "help mentions unhide --all"
state $A=hidden $C=hidden
print -r -- $A >$STATE.rec; mkdir -p $RUN/bsp; mv $STATE.rec $RECORD
bsp unhide --help
grep -q -- '--all' $S/out && [[ -z $(shown) ]] && ok "unhide --help explains --all and unhides nothing" \
    || bad "unhide --help explains --all and unhides nothing" "shown: $(shown); $(<$S/out)"
bsp unhide --bogus
(( REPLY != 0 )) && [[ -z $(shown) && -f $RECORD ]] && ok "unhide refuses an unknown argument and keeps the record" \
    || bad "unhide refuses an unknown argument and keeps the record" "status $REPLY; shown: $(shown)"

(( fail == 0 )) && print "all passed" || print "$fail failed"
exit $(( fail > 0 ))
