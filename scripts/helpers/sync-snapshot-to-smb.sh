#!/bin/bash

################################################################################
# Copy VM backups from /mnt/data/snapshot to SMB cold storage (/mnt/Backup).
# Copies the last SMB_RETENTION_DAYS (default 7) calendar days of
#   <vm>-backup-YYYYMMDD-HHMMSS.{qcow2,xml}
# then prunes older files on SMB only.
#
# Local snapshot is never deleted here. cleanup-old-backups.sh runs later and
# refuses to delete a local file unless a verified copy exists on SMB.
################################################################################

set -euo pipefail

HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HELPERS_DIR}/backup-lib.sh"

LOG_FILE="${LOG_FILE:-${SNAPSHOT_DIR}/sync-smb.log}"
DRY_RUN="${DRY_RUN:-0}"
SMB_RETENTION_DAYS="${SMB_RETENTION_DAYS:-7}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "$(dirname "$LOG_FILE")"

log_info()    { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
log_error()   { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

acquire_vm_backup_lock 10800 || exit 1

if [[ "$SMB_RETENTION_DAYS" -lt 1 ]]; then
    SMB_RETENTION_DAYS=7
fi

# Keep files whose YYYYMMDD is >= today-(N-1). N=7 → last 7 calendar days.
CUTOFF_DATE=$(date -d "-$((SMB_RETENTION_DAYS - 1)) days" +%Y%m%d)

COPIED=0
SKIPPED=0
FAILED=0

copy_file() {
    local src="$1"
    local dest="$2"
    local dest_partial="${dest}.partial"

    if [[ "$DRY_RUN" == "1" ]]; then
        log_warning "  [DRY RUN] Would copy: $src -> $dest"
        return 0
    fi

    rm -f "$dest_partial"
    if ! ionice -c 3 nice -n 10 rsync -rlt --inplace --partial --info=progress2 \
        "$src" "$dest_partial" >>"$LOG_FILE" 2>&1; then
        log_error "  rsync failed: $src"
        rm -f "$dest_partial"
        return 1
    fi

    local src_size dest_size
    src_size="$(stat -c%s "$src")"
    dest_size="$(stat -c%s "$dest_partial")"
    if [[ "$src_size" != "$dest_size" ]]; then
        log_error "  size mismatch after copy: $src ($src_size) vs $dest_partial ($dest_size)"
        rm -f "$dest_partial"
        return 1
    fi

    mv -f "$dest_partial" "$dest"
    return 0
}

sync_one_base() {
    local base="$1"
    local local_qcow="${SNAPSHOT_DIR}/${base}.qcow2"
    local local_xml="${SNAPSHOT_DIR}/${base}.xml"
    local remote_qcow="${SMB_SNAPSHOT}/${base}.qcow2"
    local remote_xml="${SMB_SNAPSHOT}/${base}.xml"

    if [[ ! -f "$local_qcow" || ! -f "$local_xml" ]]; then
        log_warning "  Incomplete local pair, skip: $base"
        (( SKIPPED++ )) || true
        return 0
    fi

    if smb_has_complete_backup "$base"; then
        log_info "  Already on SMB (size match): $base"
        (( SKIPPED++ )) || true
        return 0
    fi

    log_info "  Copying XML  $base.xml"
    if ! copy_file "$local_xml" "$remote_xml"; then
        (( FAILED++ )) || true
        return 1
    fi

    local qcow_size_h
    qcow_size_h="$(du -h "$local_qcow" | cut -f1)"
    log_info "  Copying QCOW $base.qcow2 (${qcow_size_h})"
    if ! copy_file "$local_qcow" "$remote_qcow"; then
        (( FAILED++ )) || true
        return 1
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
        log_success "  [DRY RUN] Would sync $base"
        (( COPIED++ )) || true
        return 0
    fi

    if command -v qemu-img >/dev/null; then
        if ! qemu-img info "$remote_qcow" >/dev/null 2>&1; then
            log_error "  qemu-img info failed on SMB copy: $remote_qcow"
            (( FAILED++ )) || true
            return 1
        fi
    fi

    if ! smb_has_complete_backup "$base"; then
        log_error "  Verify failed after copy: $base"
        (( FAILED++ )) || true
        return 1
    fi

    log_success "  Synced $base"
    (( COPIED++ )) || true
    return 0
}

prune_smb() {
    [[ -d "$SMB_SNAPSHOT" ]] || return 0
    log_info "Pruning SMB copies older than ${SMB_RETENTION_DAYS} days (cutoff ${CUTOFF_DATE})"

    local file basename date_str base
    while IFS= read -r -d '' file; do
        basename="$(basename "$file")"
        [[ "$basename" == *.partial ]] && continue
        date_str="$(backup_date_from_name "$basename")"
        if [[ -z "$date_str" ]]; then
            continue
        fi
        if [[ "$date_str" < "$CUTOFF_DATE" ]]; then
            if [[ "$DRY_RUN" == "1" ]]; then
                log_warning "  [DRY RUN] Would prune SMB: $file"
            else
                log_warning "  Prune SMB: $file"
                rm -f "$file"
            fi
        fi
    done < <(find "$SMB_SNAPSHOT" -maxdepth 1 \( -name '*-backup-*.qcow2' -o -name '*-backup-*.xml' \) -print0 2>/dev/null)
}

log_info "=========================================="
log_info "SMB cold-storage sync starting"
log_info "Source:      $SNAPSHOT_DIR"
log_info "Destination: $SMB_SNAPSHOT"
log_info "Keep on SMB: last ${SMB_RETENTION_DAYS} days (cutoff ${CUTOFF_DATE})"
[[ "$DRY_RUN" == "1" ]] && log_warning "DRY RUN MODE"
log_info "=========================================="

if ! ensure_smb_mounted; then
    log_error "SMB is not mounted at ${SMB_MOUNT}. Aborting (local backups will be kept)."
    exit 1
fi

# Collect bases from last N days, smallest qcow2 first to finish a restoreable
# pair sooner and to copy WiseEye before FaceID.
declare -a BASES=()
declare -A BASE_SIZE=()

for prefix in "${BACKUP_PREFIXES[@]}"; do
    shopt -s nullglob
    for qcow in "${SNAPSHOT_DIR}/${prefix}"-*.qcow2; do
        local_base="$(backup_base_from_name "$qcow")"
        date_str="$(backup_date_from_name "$local_base")"
        if [[ -z "$date_str" ]]; then
            continue
        fi
        if [[ "$date_str" < "$CUTOFF_DATE" ]]; then
            log_info "Skip local older than ${SMB_RETENTION_DAYS}d: ${local_base}"
            continue
        fi
        BASES+=("$local_base")
        BASE_SIZE["$local_base"]="$(stat -c%s "$qcow")"
    done
    shopt -u nullglob
done

if [[ ${#BASES[@]} -eq 0 ]]; then
    log_warning "No local backups in the last ${SMB_RETENTION_DAYS} days to copy."
else
    mapfile -t SORTED_BASES < <(
        for b in "${BASES[@]}"; do
            printf '%s %s\n' "${BASE_SIZE[$b]}" "$b"
        done | sort -n | awk '{print $2}'
    )
    log_info "Copy order (smallest first): ${SORTED_BASES[*]}"
    for base in "${SORTED_BASES[@]}"; do
        [[ -n "$base" ]] || continue
        sync_one_base "$base" || true
    done
fi

prune_smb

log_info "=========================================="
log_info "SMB sync summary: copied=${COPIED} skipped=${SKIPPED} failed=${FAILED}"
log_info "SMB snapshot listing:"
ls -lh "$SMB_SNAPSHOT"/*-backup-*.qcow2 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}' | tee -a "$LOG_FILE" || log_warning "  (none)"
log_info "=========================================="

if [[ "$FAILED" -gt 0 ]]; then
    log_error "One or more copies failed. Local cleanup must NOT delete those files."
    exit 1
fi

log_success "SMB cold-storage sync completed"
exit 0
