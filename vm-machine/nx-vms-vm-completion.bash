#!/bin/bash
# Bash completion script for nx-vms-vm command

_nx_vms_vm_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Available commands
    opts="create ssh start stop restart destroy status ip console list help"
    
    # Complete the first argument with available commands
    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi
}

# Register the completion function
complete -F _nx_vms_vm_completion nx-vms-vm
complete -F _nx_vms_vm_completion ./nx-vms-vm
