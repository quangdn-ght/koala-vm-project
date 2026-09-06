#!/bin/bash
# Shared helpers for VM backup, SMB cold-storage sync, and local cleanup.

SNAPSHOT_DIR="${SNAPSHOT_DIR:-/mnt/data/snapshot}"
SMB_MOUNT="${SMB_MOUNT:-/mnt/Backup}"
SMB_SNAPSHOT="${SMB_SNAPSHOT:-${SMB_MOUNT}/snapshot}"
VM_BACKUP_LOCK="${VM_BACKUP_LOCK:-/var/lock/vm-backup.lock}"
SMB_RETENTION_DAYS="${SMB_RETENTION_DAYS:-7}"

BACKUP_PREFIXES=(
    "faceid-backup"
    "wiseeye-backup"
    "fshare-backup"
    "kong-gateway-backup"
)

backup_date_from_name() {
    local name="$1"
    echo "$name" | grep -oP '\d{8}(?=-\d{6})' | head -1
}

backup_base_from_name() {
    local name="$1"
    name="$(basename "$name")"
    name="${name%.qcow2}"
    name="${name%.xml}"
    echo "$name"
}

acquire_vm_backup_lock() {
    local timeout="${1:-10800}"
    mkdir -p "$(dirname "$VM_BACKUP_LOCK")"
    exec 9>"$VM_BACKUP_LOCK"
    if ! flock -w "$timeout" 9; then
        echo "Failed to acquire ${VM_BACKUP_LOCK} within ${timeout}s" >&2
        return 1
    fi
}

ensure_smb_mounted() {
    mkdir -p "$SMB_MOUNT"
    # Trigger systemd automount
    ls "$SMB_MOUNT" >/dev/null 2>&1 || true
    if ! findmnt -n -T "$SMB_MOUNT" 2>/dev/null | grep -q cifs; then
        return 1
    fi
    mkdir -p "$SMB_SNAPSHOT"
    return 0
}

# True when SMB has both .qcow2 and .xml and qcow2 size matches local (if local exists).
smb_has_complete_backup() {
    local base="$1"
    local remote_qcow="${SMB_SNAPSHOT}/${base}.qcow2"
    local remote_xml="${SMB_SNAPSHOT}/${base}.xml"
    local local_qcow="${SNAPSHOT_DIR}/${base}.qcow2"

    [[ -f "$remote_qcow" && -f "$remote_xml" ]] || return 1

    if [[ -f "$local_qcow" ]]; then
        local local_size remote_size
        local_size="$(stat -c%s "$local_qcow")"
        remote_size="$(stat -c%s "$remote_qcow")"
        [[ "$local_size" == "$remote_size" ]] || return 1
    fi
    return 0
}
