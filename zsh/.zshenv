export ZDOTDIR=${HOME}/.config/zsh

typeset -ga _zsh_d_root=("${ZDOTDIR}/.zshenv.d"/*(N))
source "${ZDOTDIR}/.zsh.d"
