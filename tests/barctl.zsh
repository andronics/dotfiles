#!/usr/bin/env zsh
# Tests for the bar controller (barctl, dotlib _barctl; design record 0001):
# every subcommand's --help runs nothing, render's four colour tiers per
# module, the player choice, and that a source event pokes exactly the
# module whose text changed, once.
#
# Nothing live is touched: pactl, playerctl and polybar-msg are stubs on
# PATH (the pulse server and the players are files and FIFOs in a scratch
# dir; a poke is a line in a log), the state dir and every XDG dir are in
# the scratch dir, and the theme dirs are empty, so colours are the theme's
# fallback roles. The scratch dir goes under $BARCTL_TEST_TMP (default
# ${TMPDIR:-/tmp}).
#
#   zsh tests/barctl.zsh

emulate -L zsh
setopt no_unset

typeset -r REPO=${0:A:h:h}
typeset -r BASE=${BARCTL_TEST_TMP:-${TMPDIR:-/tmp}}
mkdir -p $BASE || exit 1
typeset -r S=$(mktemp -d $BASE/barctl-test.XXXXXX)
typeset -r POKES=$S/pokes BARCTL=$REPO/desktop/.local/bin/barctl

mkdir -p $S/stub $S/pa $S/xdg/{config,cache,state,runtime} $S/xdg/data/player $S/theme-config $S/theme-state
cp $REPO/shell/.local/share/player/{instances,states}.json $S/xdg/data/player/
chmod 700 $S/xdg/runtime
mkfifo $S/pa.fifo $S/pl.fifo

# pactl: the server is up while $S/pa/up exists; the sink's volume and mute
# are files; subscribe streams whatever the test writes to pa.fifo.
print -r -- '#!/bin/sh
P='$S'/pa
[ -e $P/up ] || { echo "Connection failure: Connection refused" >&2; exit 1; }
case "$1" in
    subscribe) exec cat '$S'/pa.fifo ;;
    get-default-sink) echo alsa_output.test ;;
    get-sink-volume) echo "Volume: front-left: 22937 /  $(cat $P/vol)% / -27.36 dB,   front-right: 22937 /  $(cat $P/vol)% / -27.36 dB" ;;
    get-sink-mute) echo "Mute: $(cat $P/mute)" ;;
    *) echo "pactl stub: $*" >>'$S'/unexpected; exit 1 ;;
esac' >$S/stub/pactl
# playerctl: -l lists $S/players; the follow stream is pl.fifo.
print -r -- '#!/bin/sh
case "$*" in
    -l) cat '$S'/players 2>/dev/null ;;
    "-a --follow metadata --format "*) exec cat '$S'/pl.fifo ;;
    *) echo "playerctl stub: $*" >>'$S'/unexpected; exit 1 ;;
esac' >$S/stub/playerctl
print -r -- '#!/bin/sh
echo "$*" >>'$POKES >$S/stub/polybar-msg
chmod +x $S/stub/*

export DOTLIB=$REPO/shell/.local/share/dotlib BARCTL_STATE_DIR=$S/state
export XDG_CONFIG_HOME=$S/xdg/config XDG_CACHE_HOME=$S/xdg/cache XDG_DATA_HOME=$S/xdg/data
export XDG_STATE_HOME=$S/xdg/state XDG_RUNTIME_DIR=$S/xdg/runtime
export THEME_CONFIG_DIR=$S/theme-config THEME_STATE_DIR=$S/theme-state
export BARCTL_RETRY=60 BARCTL_SUPERVISE=1
export PATH="$S/stub:$PATH"

integer pass=0 fail=0
typeset -a bg=()
cleanup() {
    local p
    for p in $bg; do kill $p 2>/dev/null; done
    rm -rf $S
}
trap cleanup EXIT

ok()  { (( ++pass )); print "ok   $1"; }
bad() { (( ++fail )); print "FAIL $1${2:+: $2}"; }

pokes() { [[ -s $POKES ]] && print -r -- "$(<$POKES)"; }
npokes() { local n=0; [[ -s $POKES ]] && n=${#${(f)"$(<$POKES)"}}; print $n; }
# until_ <seconds> <command...>: true once the command is.
until_() {
    local -i i n=$(( $1 * 20 )); shift
    for (( i = 0; i < n; i++ )); do "$@" && return 0; sleep 0.05; done
    return 1
}
# settle <count>: waits for the poke log to reach <count> lines, then a
# little longer, so a stray extra poke would show.
settle() { until_ 3 eval '(( $(npokes) >= '$1' ))'; sleep 0.3; }
tier() { local l=; [[ -r $S/state/$1 ]] && l=$(<$S/state/$1); print -r -- "${l%%$'\t'*}"; }
text() { local l=; [[ -r $S/state/$1 ]] && l=$(<$S/state/$1); print -r -- "${l#*$'\t'}"; }

typeset -r MODS=(audio-level player-play-pause player-metadata)

print "== --help runs nothing"
for sub in run render poke status; do
    out=$(zsh -f $BARCTL $sub --help 2>&1); rc=$?
    [[ $rc == 0 && $out == "usage: barctl $sub"* && ! -e $S/state && -z $(pokes) ]] \
        && ok "help-$sub" || bad "help-$sub" "rc=$rc out=$out pokes=$(pokes) state=$(ls $S/state 2>&1)"
done
out=$(zsh -f $BARCTL --help 2>&1); rc=$?
[[ $rc == 0 && $out == *run* && $out == *render* && $out == *poke* && $out == *status* ]] \
    && ok help-top || bad help-top "rc=$rc"
out=$(zsh -f $BARCTL help render 2>&1); rc=$?
[[ $rc == 0 && $out == "usage: barctl render"* && -z $(pokes) ]] && ok help-sub-form || bad help-sub-form "$out"

print "== render: four tiers per module, from the theme's roles"
typeset -A role
while read -r k v; do role[$k]=$v; done < <(zsh -f -c 'source $DOTLIB/_theme >/dev/null 2>&1; theme-roles unavailable=dim idle=fg_dim active=accent alert=urgent')
[[ ${#role} == 4 && ${#${(u)role}} == 4 ]] && ok roles-distinct || bad roles-distinct "${(kv)role}"
mkdir -p $S/state
for m in $MODS; do
    for t in unavailable idle active alert; do
        print -r -- "$t"$'\t'"text of $m" >| $S/state/$m
        out=$(zsh -f $BARCTL render $m 2>&1)
        [[ $out == "%{F${role[$t]}}text of $m%{F-}" ]] && ok "render-$m-$t" || bad "render-$m-$t" "$out"
    done
done
rm -f $S/state/*
out=$(zsh -f $BARCTL render audio-level)
[[ $out == "%{F${role[unavailable]}}"*"%{F-}" ]] && ok render-no-state || bad render-no-state "$out"
out=$(zsh -f $BARCTL render player-metadata)
[[ -z $out ]] && ok render-empty-metadata || bad render-empty-metadata "$out"
out=$(zsh -f $BARCTL render ../etc 2>&1); rc=$?
[[ $rc != 0 ]] && ok render-bad-name || bad render-bad-name "rc=$rc"
[[ -z $(pokes) ]] && ok render-pokes-nothing || bad render-pokes-nothing "$(pokes)"

print "== player choice"
# pick <events...>: feeds each event line (instance|name|status|artist|title)
# to the player watcher's handler with every listed player live; prints the
# chosen instance. Pokes go to the log, which is reset after.
pick() {
    zsh -f -c '
        source $DOTLIB/_barctl
        _PLAYER_INSTANCES_DATA=[] _PLAYER_STATES_DATA=[]
        for e in "$@"; do _barctl-player-event "${e//|/$_BARCTL_US}"; done
        _barctl-player-pick; print -r -- $REPLY' pick "$@"
}
print -l spotify firefox mpv >| $S/players
mkdir -p $S/state
check() {
    local name=$1 want=$2; shift 2
    local got; got=$(pick "$@")
    [[ "$got" == "$want" ]] && ok "pick-$name" || bad "pick-$name" "want $want got $got"
}
check playing-beats-paused spotify 'spotify|spotify|Playing|a|b' 'firefox|firefox|Paused|a|b'
check paused-beats-stopped firefox 'spotify|spotify|Stopped|a|b' 'firefox|firefox|Paused|a|b' 'mpv|mpv|Stopped|a|b'
check latest-playing firefox 'spotify|spotify|Playing|a|b' 'firefox|firefox|Playing|a|b'
check latest-status-change spotify 'spotify|spotify|Playing|a|b' 'firefox|firefox|Playing|a|b' 'spotify|spotify|Paused|a|b' 'spotify|spotify|Playing|a|b'
check track-change-is-not-status firefox 'spotify|spotify|Playing|a|b' 'firefox|firefox|Playing|a|b' 'spotify|spotify|Playing|a|c'
check both-paused-latest spotify 'firefox|firefox|Paused|a|b' 'spotify|spotify|Paused|a|b'
print -l firefox >| $S/players
check gone-player-dropped firefox 'spotify|spotify|Playing|a|b' 'firefox|firefox|Paused|a|b' ''
print -n >| $S/players
check none-left '' 'spotify|spotify|Playing|a|b' ''
rm -rf $S/state; : >| $POKES

# start <source>: runs that watcher in the background with the stubs.
start() {
    zsh -f -c 'source $DOTLIB/_barctl; mkdir -p $BARCTL_STATE_DIR; _barctl-source-'$1 &
    bg+=($!)
}

print "== volume: pactl subscribe drives audio-level"
touch $S/pa/up; print 35 >| $S/pa/vol; print no >| $S/pa/mute
# The FIFOs open after the watcher starts, so it holds no writer of its own
# and closing ours ends its stream.
start volume
exec {PA}<>$S/pa.fifo
settle 1
[[ $(pokes) == 'action #audio-level.hook.0' && $(tier audio-level) == active && $(text audio-level) == *'35% ' ]] \
    && ok volume-start || bad volume-start "pokes=$(pokes) tier=$(tier audio-level) text=$(text audio-level)"
print yes >| $S/pa/mute
print -u $PA "Event 'change' on sink #57"
settle 2
[[ $(npokes) == 2 && ${${(f)"$(pokes)"}[2]} == 'action #audio-level.hook.0' && $(tier audio-level) == idle ]] \
    && ok volume-mute-one-poke || bad volume-mute-one-poke "pokes=$(npokes) tier=$(tier audio-level)"
print 60 >| $S/pa/vol
print -u $PA "Event 'change' on sink-input #12"
settle 3
[[ $(npokes) == 2 ]] && ok volume-ignores-sink-input || bad volume-ignores-sink-input "pokes=$(npokes)"
print no >| $S/pa/mute
print -u $PA "Event 'change' on server #1"
settle 3
[[ $(npokes) == 3 && $(tier audio-level) == active && $(text audio-level) == *'60% ' ]] \
    && ok volume-server-event || bad volume-server-event "pokes=$(npokes) text=$(text audio-level)"
print -u $PA "Event 'change' on sink #57"
settle 4
[[ $(npokes) == 3 ]] && ok volume-unchanged-no-poke || bad volume-unchanged-no-poke "pokes=$(npokes)"
rm -f $S/pa/up
exec {PA}>&-
settle 4
[[ $(npokes) == 4 && $(tier audio-level) == unavailable ]] \
    && ok volume-server-gone || bad volume-server-gone "pokes=$(npokes) tier=$(tier audio-level)"
kill ${bg[-1]} 2>/dev/null
[[ ! -s $S/unexpected ]] && ok volume-no-other-pactl || bad volume-no-other-pactl "$(<$S/unexpected)"
rm -rf $S/state; : >| $POKES

print "== player: playerctl --follow drives player-play-pause and player-metadata"
US=$'\x1f'
ev() { print -u $PL -r -- "${1//|/$US}"; }
print -l spotify >| $S/players
start player
exec {PL}<>$S/pl.fifo
settle 2
[[ $(npokes) == 2 && $(tier player-play-pause) == unavailable && $(tier player-metadata) == unavailable ]] \
    && ok player-start-none || bad player-start-none "pokes=$(pokes)"
: >| $POKES
ev 'spotify|spotify|Playing|Dear Rouge|I Heard I Had'
settle 2
[[ $(npokes) == 2 && $(pokes) == *'#player-play-pause.hook.0'* && $(pokes) == *'#player-metadata.hook.0'* \
    && $(tier player-play-pause) == active && $(text player-metadata) == 'Dear Rouge: I Heard I Had' ]] \
    && ok player-playing || bad player-playing "pokes=$(pokes) meta=$(text player-metadata)"
# instances.json's spotify icon, then states.json's playing glyph.
[[ $(text player-play-pause) == $' ' ]] && ok player-icon || bad player-icon "$(text player-play-pause)"
: >| $POKES
ev 'spotify|spotify|Playing|Dear Rouge|Next Song'
settle 1
[[ $(pokes) == 'action #player-metadata.hook.0' ]] && ok player-track-one-poke || bad player-track-one-poke "$(pokes)"
: >| $POKES
ev 'spotify|spotify|Playing|Dear Rouge|Next Song'
settle 1
[[ -z $(pokes) ]] && ok player-same-no-poke || bad player-same-no-poke "$(pokes)"
ev 'spotify|spotify|Paused|Dear Rouge|Next Song'
settle 2
[[ $(tier player-play-pause) == idle && $(tier player-metadata) == idle && $(npokes) == 2 ]] \
    && ok player-paused-idle || bad player-paused-idle "pokes=$(pokes)"
: >| $POKES
ev 'spotify|spotify|Playing|An Artist With A Long Name|And A Title Long Enough To Be Cut %{F#ff0000}'
settle 2
m=$(text player-metadata)
[[ ${#m} == 40 && $m == *… && $m != *'%{F'* ]] && ok player-metadata-40 || bad player-metadata-40 "${#m} $m"
ev 'spotify|spotify|Playing|x|%{F#ff0000}red'
settle 3
[[ $(text player-metadata) == 'x: %%{F#ff0000}red' ]] && ok player-escape || bad player-escape "$(text player-metadata)"
exec {PL}>&-
kill ${bg[-1]} 2>/dev/null
[[ ! -s $S/unexpected ]] && ok player-no-other-playerctl || bad player-no-other-playerctl "$(<$S/unexpected)"
rm -rf $S/state; : >| $POKES

print "== run: both watchers as children, one controller, clean stop"
touch $S/pa/up; print 35 >| $S/pa/vol; print no >| $S/pa/mute
print -n >| $S/players
zsh -f $BARCTL run 2>$S/run.err &
runpid=$!; bg+=($runpid)
exec {PA}<>$S/pa.fifo {PL}<>$S/pl.fifo
settle 3
[[ $(npokes) == 3 ]] && ok run-pokes-all || bad run-pokes-all "pokes=$(pokes)"
out=$(zsh -f $BARCTL status)
[[ $out == *"controller: running (pid $runpid)"* && $out == *audio-level*active* && $out == *player-play-pause*unavailable* ]] \
    && ok run-status || bad run-status "$out"
out=$(zsh -f $BARCTL run 2>&1); rc=$?
[[ $rc != 0 && $out == *'already running'* ]] && ok run-single || bad run-single "rc=$rc $out"
kids=($(pgrep -x -P $runpid zsh))
[[ ${#kids} == 2 ]] && ok run-two-watchers || bad run-two-watchers "children: $kids"
print -l mpv >| $S/players
: >| $POKES
ev 'mpv|mpv|Playing|a|b'
settle 2
[[ $(npokes) == 2 && $(tier player-play-pause) == active ]] && ok run-player-event || bad run-player-event "$(pokes)"
kill -TERM $runpid
until_ 3 eval '! kill -0 '$runpid' 2>/dev/null' && ok run-stops || bad run-stops
sleep 0.3
left=$(pgrep -f "cat $S/p" 2>/dev/null)
[[ -z $left && ! -e $S/state/pid ]] && ok run-cleans-up || bad run-cleans-up "left=$left pid=$(ls $S/state)"
out=$(zsh -f $BARCTL status)
[[ $out == *'controller: not running'* ]] && ok status-not-running || bad status-not-running "$out"
exec {PA}>&- {PL}>&-

print "== poke"
: >| $POKES
zsh -f $BARCTL poke audio-level
[[ $(pokes) == 'action #audio-level.hook.0' ]] && ok poke || bad poke "$(pokes)"

print
print "$pass passed, $fail failed"
(( fail == 0 ))
