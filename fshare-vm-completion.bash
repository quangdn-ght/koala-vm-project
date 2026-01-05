#!/bin/bash
# Bash completion for fshare-vm script

_fshare_vm_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Add any command-line options here if needed
    opts="--help --status --start --stop --restart --console --ip"
    
    if [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi
}

complete -F _fshare_vm_completion fshare-vm
