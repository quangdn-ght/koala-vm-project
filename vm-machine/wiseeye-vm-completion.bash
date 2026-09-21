#!/bin/bash
# Bash completion for wiseeye-vm script

_wiseeye_vm_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Available commands
    opts="create ssh start stop restart destroy status ip console list backup list-backups restore setup-network setup-bridge setup-static-ip setup-nvme setup-env generate-preseed test-preseed help"
    
    # Special completion for restore command (list available backup timestamps)
    if [ "$prev" == "restore" ]; then
        if [ -d /mnt/data/snapshot ]; then
            local backups=$(ls -1 /mnt/data/snapshot/wiseeye-backup-*.qcow2 2>/dev/null | sed 's/.*wiseeye-backup-\(.*\)\.qcow2/\1/')
            COMPREPLY=( $(compgen -W "${backups}" -- ${cur}) )
        fi
        return 0
    fi
    
    COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
    return 0
}

complete -F _wiseeye_vm_completion wiseeye-vm
complete -F _wiseeye_vm_completion ./wiseeye-vm
