export ZDOTDIR=${HOME}/.config/zsh

if [[ -d ${ZDOTDIR}/.zshenv.d ]]; then
    typeset -ga _zsh_d_root=("${ZDOTDIR}/.zshenv.d"/*(N))
    source "${ZDOTDIR}/.zsh.d"
fi
