# Add deno completions to search path
if [[ ":$FPATH:" != *":/home/andronics/.config/zsh/completions:"* ]]; then export FPATH="/home/andronics/.config/zsh/completions:$FPATH"; fi
typeset -ga _zsh_d_root=("${ZDOTDIR}/.zshrc.d"/*(N))
source "${ZDOTDIR}/.zsh.d"
# . "/home/andronics/.deno/env"
# # Initialize zsh completions (added by deno install script)
# autoload -Uz compinit
# compinit
# pnpm
export PNPM_HOME="/home/andronics/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
