#!/usr/bin/env zsh
# Theme text contrast (dotfiles record 0004): for every scheme in the repo,
# the contrast of fg_dim and dim on bg and on bg_alt, and fg_dim : dim, before
# the resolver's fix-ups (raw: the scheme's slots) and after (res), then the
# cells below the floors on the worse of the two surfaces (fg_dim 4.5, dim 3.0),
# and Catppuccin's subtext1 on bg_alt (rofi's placeholder before record 0004,
# which made it fg_dim in every scheme).
#
# Works from the repo: sources this checkout's _theme with THEME_CONFIG_DIR at
# its desktop/.config/theme and THEME_STATE_DIR at a scratch dir, and calls the
# resolver only (_theme-resolve-source). Nothing is rendered, applied, swapped
# or reloaded, and the live state (~/.local/state/theme) is never read.
# A measurement: it exits 0 whatever it finds, 1 only when a scheme can't be
# resolved. Until record 0004 is built, `res` has cells below the floors.
#
#   zsh tests/theme-contrast-measure.zsh

emulate -L zsh
setopt no_unset

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

c() { colour-contrast "$1" "$2"; printf '%.2f' $REPLY; }
integer failed=0
typeset -a below

print -r -- "# floors: fg_dim >= $_THEME_MIN_FG_DIM, dim >= $_THEME_MIN_DIM (record 0004: on the worse of bg and bg_alt)"
print -r -- "# raw = the scheme's slots before the resolver's fix-ups; res = after _theme-resolve"
print -r -- "scheme|variant|stage|bg|bg_alt|surface|fg|fg_dim|dim|fg/bg|fg/bg_alt|fg_dim/bg|fg_dim/bg_alt|fg_dim/surface|dim/bg|dim/bg_alt|dim/surface|fg_dim:dim|adjusted"
for f in "$THEME_CONFIG_DIR"/schemes/*.yaml; do
    s=${f:t:r}
    if ! _theme-load-source "$s" >/dev/null 2>&1 || ! _theme-palette; then
        print -r -- "$s|load failed"; (( ++failed )); continue
    fi
    typeset -A raw=()
    for role k in "${(@kv)_THEME_ROLE_SLOTS}"; do raw[$role]=${_THEME_PAL[$k]}; done
    for k v in "${(@kv)_THEME_IN}"; do
        [[ "$k" == scheme.x-roles.* ]] || continue
        r=${k#scheme.x-roles.}
        [[ -n "${raw[$r]+x}" ]] || continue
        _theme-ref "$v" && raw[$r]=$REPLY
    done
    if ! _theme-resolve 2>/dev/null; then
        print -r -- "$s|resolve failed: ${(j:; :)_THEME_NOTES}"; (( ++failed )); continue
    fi
    typeset -A res=("${(@kv)_THEME_ROLE}")
    for stage in raw res; do
        typeset -A R=("${(@kvP)stage}")
        adj=-; [[ $stage == res ]] && adj=${(j:,:)_THEME_ADJUSTED:-none}
        print -r -- "$s|$_THEME_MODE|$stage|${R[bg]}|${R[bg_alt]}|${R[surface]}|${R[fg]}|${R[fg_dim]}|${R[dim]}|$(c ${R[fg]} ${R[bg]})|$(c ${R[fg]} ${R[bg_alt]})|$(c ${R[fg_dim]} ${R[bg]})|$(c ${R[fg_dim]} ${R[bg_alt]})|$(c ${R[fg_dim]} ${R[surface]})|$(c ${R[dim]} ${R[bg]})|$(c ${R[dim]} ${R[bg_alt]})|$(c ${R[dim]} ${R[surface]})|$(c ${R[fg_dim]} ${R[dim]})|$adj"
    done
    for role floor in fg_dim $_THEME_MIN_FG_DIM dim $_THEME_MIN_DIM; do
        for surf in bg bg_alt; do
            colour-contrast "${res[$role]}" "${res[$surf]}"
            (( REPLY < floor )) && below+=("$s: $role on $surf $(printf '%.2f' $REPLY) < $floor")
        done
    done
done

# rofi's placeholder (fg-alt-color) was the palette's subtext1 where a scheme
# names one (Catppuccin), bypassing the resolver; it sits on bg_alt. Since
# record 0004 it is fg_dim, so the fg_dim/bg_alt column above covers it.
typeset -a placeholder
for f in "$THEME_CONFIG_DIR"/schemes/*.yaml; do
    s=${f:t:r}
    _theme-resolve-source "$s" >/dev/null 2>&1 || continue
    sub=${_THEME_PAL[subtext1]:-}
    [[ -n "$sub" ]] || continue
    colour-contrast "$sub" "${_THEME_ROLE[bg_alt]}"
    placeholder+=("$s: subtext1 $sub on bg_alt ${_THEME_ROLE[bg_alt]} $(printf '%.2f' $REPLY)")
done
print -r -- "# subtext1 on bg_alt (rofi's placeholder before record 0004; now fg_dim):"
print -rl -- "#   "${^placeholder}

print -r -- "# below the floors after the resolver: ${#below}"
(( ${#below} )) && print -rl -- "#   "${^below}
(( failed == 0 ))
