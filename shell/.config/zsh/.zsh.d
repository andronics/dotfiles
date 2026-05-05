typeset -g _zsh_d_file

for _zsh_d_file in ${(o)_zsh_d_root}; do
    [[ ${_zsh_d_file:t} != '~'* ]] || continue
    source "${_zsh_d_file}"
done

unset _zsh_d_{root,file}

