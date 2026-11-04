#!/usr/bin/env zsh
# Theme text contrast, options (dotfiles record 0004): projects options (a) and
# (b) onto every scheme in the repo. Starts from today's resolved roles and
# applies each option's floors with the resolver's own helpers
# (colour-ensure-contrast, colour-fit-contrast) against the worse of bg and
# bg_alt. A projection, not the build: the real change may differ.
#   (a) fg_dim >= 4.5, dim >= 3.0 on both; dim kept below fg_dim on both
#       (refitted to 3.0 on the worse surface if not)
#   (b) dim >= 4.5 on both; fg_dim >= 4.5 x 1.3 = 5.85 on both, a step above dim
# Columns: each role's contrast on both surfaces, fg_dim : dim and fg : fg_dim
# on the worse surface, and how far each role moved from today (ΔE, OKLab).
#
# Works from the repo, as tests/theme-contrast-measure.zsh does: this
# checkout's _theme, THEME_STATE_DIR in a scratch dir removed after, the
# resolver only. Nothing is rendered, applied or reloaded. Exits 1 only when a
# scheme can't be resolved.
#
#   zsh tests/theme-contrast-project.zsh

emulate -L zsh

typeset -r REPO=${0:A:h:h}
scratch=$(mktemp -d "${TMPDIR:-/tmp}/theme-contrast.XXXXXX") || exit 1
trap 'rm -rf -- "${scratch:?}"' EXIT

export DOTLIB="$REPO/shell/.local/share/dotlib"
export THEME_CONFIG_DIR="$REPO/desktop/.config/theme"
export THEME_STATE_DIR="$scratch/state" THEME_CACHE_DIR="$scratch/cache"
export TOOL_JOURNAL=off TOOL_STATS=skip
mkdir -p "$THEME_STATE_DIR"
source "$DOTLIB/_theme" || exit 1
_theme-paths

integer failed=0
cr() { colour-contrast "$1" "$2"; }
# REPLY = whichever of bg, bg_alt gives colour $1 the lower contrast
worse() { local -F a b; cr $1 $bg; a=$REPLY; cr $1 $alt; b=$REPLY; (( a <= b )) && REPLY=$bg || REPLY=$alt; }
lift() { worse $1; colour-ensure-contrast $1 $REPLY $2 || print -u2 "$s: $3 cannot reach $2"; }
f() { printf '%.2f' $1; }

print -r -- "scheme|option|fg_dim|dim|fg_dim/bg|fg_dim/bg_alt|dim/bg|dim/bg_alt|fg_dim:dim(worse)|fg:fg_dim(worse)|dE fg_dim|dE dim"
for file in "$THEME_CONFIG_DIR"/schemes/*.yaml; do
    s=${file:t:r}
    _theme-resolve-source "$s" >/dev/null 2>&1 || { print -r -- "$s|resolve failed"; (( ++failed )); continue; }
    bg=${_THEME_ROLE[bg]} alt=${_THEME_ROLE[bg_alt]} fg=${_THEME_ROLE[fg]}
    fd0=${_THEME_ROLE[fg_dim]} d0=${_THEME_ROLE[dim]}
    for opt in today a b; do
        fd=$fd0 d=$d0
        case $opt in
        a)  lift $fd 4.5 fg_dim; fd=$REPLY
            lift $d 3.0 dim; d=$REPLY
            local -F x1 x2 y1 y2
            cr $d $bg; x1=$REPLY; cr $fd $bg; y1=$REPLY; cr $d $alt; x2=$REPLY; cr $fd $alt; y2=$REPLY
            if (( x1 >= y1 || x2 >= y2 )); then worse $d; colour-fit-contrast $d $REPLY 3.0; d=$REPLY; fi ;;
        b)  lift $d 4.5 dim; d=$REPLY
            lift $fd 5.85 fg_dim; fd=$REPLY ;;
        esac
        local -F a1 a2 b1 b2 g1 g2 wf wd wg e1 e2
        cr $fd $bg; a1=$REPLY; cr $fd $alt; a2=$REPLY; cr $d $bg; b1=$REPLY; cr $d $alt; b2=$REPLY
        cr $fg $bg; g1=$REPLY; cr $fg $alt; g2=$REPLY
        wf=$(( a1 < a2 ? a1 : a2 )); wd=$(( b1 < b2 ? b1 : b2 )); wg=$(( g1 < g2 ? g1 : g2 ))
        colour-delta-e $fd $fd0; e1=$REPLY; colour-delta-e $d $d0; e2=$REPLY
        print -r -- "$s|$opt|$fd|$d|$(f $a1)|$(f $a2)|$(f $b1)|$(f $b2)|$(f $(( wf / wd )))|$(f $(( wg / wf )))|$(f $e1)|$(f $e2)"
    done
done
(( failed == 0 ))
