typeset -ga _zsh_d_root=("${ZDOTDIR}/.zshrc.d"/*(N))
source "${ZDOTDIR}/.zsh.d"

autoload -Uz compinit
# compinit -C trusts the dump, so it never sees a new or changed #compdef.
# A full compinit rewrites the dump only when the count of files on fpath
# changes, so the stale dump is removed first: it is rebuilt with a fresh
# mtime and the next shells go back to -C. Stale means missing, over 24h old,
# or older than a file in completions/ or in the brain's generated dir
# (BRAIN_COMPLETIONS, from 05-completions; absent on servers). The age test is
# an array glob: a qualifier glob inside [[ -n ... ]] is never expanded, so it
# is always true. The brain glob is behind -d so an empty variable never globs /.
_zcd=${ZDOTDIR}/.zcompdump
_zcd_old=(${_zcd}(N.mh+24))
_zcd_new=(${ZDOTDIR}/completions/*(N-.om[1]))
_zcd_brain=()
[[ -n $BRAIN_COMPLETIONS && -d $BRAIN_COMPLETIONS ]] && _zcd_brain=($BRAIN_COMPLETIONS/*(N-.om[1]))
if [[ ! -e $_zcd ]] || (( $#_zcd_old )) || [[ -n $_zcd_new && $_zcd_new[1] -nt $_zcd ]] \
    || [[ -n $_zcd_brain && $_zcd_brain[1] -nt $_zcd ]]; then
    rm -f -- "$_zcd"
    compinit
else
    compinit -C
fi
unset _zcd _zcd_old _zcd_new _zcd_brain
