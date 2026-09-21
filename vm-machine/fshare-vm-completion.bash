#!/bin/bash

################################################################################
# Bash Completion for fshare-vm script
# Provides tab completion for all commands
################################################################################

_fshare_vm_completion() {
    local cur prev commands
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # All available commands
    commands="create ssh ssh2 start stop restart destroy status ip console list java maven gradle setup-env ping backup list-backups restore help"

    # If we're completing the first argument (command)
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
        return 0
    fi

    # Special completion for restore command (suggest available backups)
    if [[ ${prev} == "restore" ]]; then
        if [[ -d /mnt/data/snapshot ]]; then
            local backups=$(ls /mnt/data/snapshot/fshare-backup-*.qcow2 2>/dev/null | sed 's/.*fshare-backup-\(.*\)\.qcow2/\1/' | tr '\n' ' ')
            COMPREPLY=($(compgen -W "${backups}" -- "${cur}"))
        fi
        return 0
    fi
}

# Register the completion function
complete -F _fshare_vm_completion ./fshare-vm
complete -F _fshare_vm_completion fshare-vm
