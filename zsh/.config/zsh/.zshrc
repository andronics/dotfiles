typeset -ga _zsh_d_root=("${ZDOTDIR}/.zshrc.d"/*(N))
source "${ZDOTDIR}/.zsh.d"

autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi
