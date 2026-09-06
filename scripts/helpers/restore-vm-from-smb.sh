#!/bin/bash

################################################################################
# Restore a complete VM from SMB cold storage (/mnt/Backup/snapshot).
#
#   restore-vm-from-smb.sh list
#   restore-vm-from-smb.sh fetch   <vm> <timestamp>
#   restore-vm-from-smb.sh restore <vm> <timestamp> --yes
#
# fetch  : copy .qcow2 + .xml from SMB back to /mnt/data/snapshot
# restore: fetch, stop VM, replace live disk with the backup, start VM
#
# <vm> is the backup prefix without -backup, e.g. faceid | wiseeye | kong-gateway
################################################################################

set -euo pipefail

HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HELPERS_DIR}/backup-lib.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage:
  $(basename "$0") list
  $(basename "$0") fetch   <vm> <timestamp>
  $(basename "$0") restore <vm> <timestamp> --yes

Examples:
  $(basename "$0") list
  $(basename "$0") fetch   faceid 20260906-000001
  $(basename "$0") restore faceid 20260906-000001 --yes
EOF
}

live_disk_for_vm() {
    local vm="$1"
    case "$vm" in
        faceid) echo "/mnt/data/faceid.qcow2" ;;
        wiseeye) echo "/mnt/data/vm-images/wiseeye-vm.qcow2" ;;
        kong-gateway|fshare) echo "/mnt/data/kong-gateway.qcow2" ;;
        *) echo "" ;;
    esac
}

libvirt_name_for_vm() {
    local vm="$1"
    case "$vm" in
        fshare) echo "kong-gateway" ;;
        *) echo "$vm" ;;
    esac
}

cmd="${1:-}"
if [[ -z "$cmd" || "$cmd" == "-h" || "$cmd" == "--help" ]]; then
    usage
    exit 0
fi

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

if ! ensure_smb_mounted; then
    echo -e "${RED}SMB is not mounted at ${SMB_MOUNT}${NC}"
    exit 1
fi

list_backups() {
    echo -e "${GREEN}SMB cold storage: ${SMB_SNAPSHOT}${NC}"
    if ! ls "${SMB_SNAPSHOT}"/*-backup-*.qcow2 >/dev/null 2>&1; then
        echo "  (empty)"
        return 0
    fi
    printf '%-22s %-18s %8s %6s %s\n' "FILE" "TIMESTAMP" "SIZE" "XML" "QEMU"
    for qcow in "${SMB_SNAPSHOT}"/*-backup-*.qcow2; do
        local base ts size xml_ok qemu_ok
        base="$(backup_base_from_name "$qcow")"
        ts="$(echo "$base" | grep -oP '\d{8}-\d{6}' | head -1)"
        size="$(du -h "$qcow" | cut -f1)"
        xml_ok="no"
        qemu_ok="no"
        [[ -f "${SMB_SNAPSHOT}/${base}.xml" ]] && xml_ok="yes"
        if qemu-img info "$qcow" >/dev/null 2>&1; then
            qemu_ok="ok"
        fi
        printf '%-22s %-18s %8s %6s %s\n' "$base" "$ts" "$size" "$xml_ok" "$qemu_ok"
    done
}

fetch_pair() {
    local vm="$1"
    local ts="$2"
    local base="${vm}-backup-${ts}"
    local remote_qcow="${SMB_SNAPSHOT}/${base}.qcow2"
    local remote_xml="${SMB_SNAPSHOT}/${base}.xml"
    local local_qcow="${SNAPSHOT_DIR}/${base}.qcow2"
    local local_xml="${SNAPSHOT_DIR}/${base}.xml"

    if [[ ! -f "$remote_qcow" || ! -f "$remote_xml" ]]; then
        echo -e "${RED}Complete pair not found on SMB:${NC}"
        echo "  $remote_qcow"
        echo "  $remote_xml"
        exit 1
    fi

    mkdir -p "$SNAPSHOT_DIR"
    echo -e "${BLUE}Copying XML -> ${local_xml}${NC}"
    rsync -rlt --inplace --info=progress2 "$remote_xml" "$local_xml"
    echo -e "${BLUE}Copying QCOW -> ${local_qcow}${NC}"
    rsync -rlt --inplace --partial --info=progress2 "$remote_qcow" "$local_qcow"

    local rs ls_
    rs="$(stat -c%s "$remote_qcow")"
    ls_="$(stat -c%s "$local_qcow")"
    if [[ "$rs" != "$ls_" ]]; then
        echo -e "${RED}Size mismatch after fetch${NC}"
        exit 1
    fi
    qemu-img info "$local_qcow" >/dev/null
    echo -e "${GREEN}Fetched ${base} to ${SNAPSHOT_DIR}${NC}"
}

restore_live() {
    local vm="$1"
    local ts="$2"
    local yes="${3:-}"
    local domain
    domain="$(libvirt_name_for_vm "$vm")"
    local live
    live="$(live_disk_for_vm "$vm")"
    local base="${vm}-backup-${ts}"
    local local_qcow="${SNAPSHOT_DIR}/${base}.qcow2"
    local stamp
    stamp="$(date +%Y%m%d-%H%M%S)"

    if [[ "$yes" != "--yes" ]]; then
        echo -e "${RED}Refusing to replace live disk without --yes${NC}"
        usage
        exit 1
    fi
    if [[ -z "$live" ]]; then
        echo -e "${RED}Unknown VM: $vm${NC}"
        exit 1
    fi

    fetch_pair "$vm" "$ts"

    echo -e "${YELLOW}Stopping ${domain} (if running)...${NC}"
    virsh destroy "$domain" 2>/dev/null || true

    if [[ -f "$live" ]]; then
        echo "Moving current disk aside: ${live}.pre-restore-${stamp}"
        mv -f "$live" "${live}.pre-restore-${stamp}"
    fi

    echo -e "${BLUE}Restoring disk to ${live}${NC}"
    mkdir -p "$(dirname "$live")"
    rsync -rlt --inplace --partial --info=progress2 "$local_qcow" "$live"

    echo "Defining domain from backup XML (if needed)..."
    virsh define "${SNAPSHOT_DIR}/${base}.xml" >/dev/null 2>&1 || true

    echo "Starting ${domain}..."
    virsh start "$domain"
    echo -e "${GREEN}Restore complete. Previous disk: ${live}.pre-restore-${stamp}${NC}"
}

case "$cmd" in
    list)
        list_backups
        ;;
    fetch)
        [[ -n "${2:-}" && -n "${3:-}" ]] || { usage; exit 1; }
        fetch_pair "$2" "$3"
        ;;
    restore)
        [[ -n "${2:-}" && -n "${3:-}" ]] || { usage; exit 1; }
        restore_live "$2" "$3" "${4:-}"
        ;;
    *)
        usage
        exit 1
        ;;
esac
