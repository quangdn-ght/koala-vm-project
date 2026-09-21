#!/bin/bash

################################################################################
# Bash Completion for faceid-vm script
# Provides tab completion for all commands
################################################################################

_faceid_vm_completions() {
    local cur prev commands
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # All available commands
    commands="create ssh start stop restart destroy status ip console list backup list-backups restore setup-network setup-bridge setup-static-ip setup-nvme setup-env generate-preseed test-preseed help"

    # If we're completing the first argument (command)
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
        return 0
    fi

    # Special completion for restore command (suggest available backups)
    if [[ ${prev} == "restore" ]]; then
        if [[ -d /mnt/data/snapshot ]]; then
            local backups=$(ls /mnt/data/snapshot/faceid-backup-*.qcow2 2>/dev/null | sed 's/.*faceid-backup-\(.*\)\.qcow2/\1/' | tr '\n' ' ')
            COMPREPLY=($(compgen -W "${backups}" -- "${cur}"))
        fi
        return 0
    fi
}

# Register the completion function
complete -F _faceid_vm_completions ./faceid-vm
complete -F _faceid_vm_completions faceid-vm
