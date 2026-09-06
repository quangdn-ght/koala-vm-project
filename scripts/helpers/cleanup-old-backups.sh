#!/bin/bash

################################################################################
# Cleanup Old Backup Files
# Only /mnt/data/snapshot — keep today's backups, delete files from day 2 onward.
# Does not touch /mnt/data/vm-images or leftover overlays under /mnt/data/.
################################################################################

set -euo pipefail

HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HELPERS_DIR}/backup-lib.sh"

RETENTION_DAYS="${RETENTION_DAYS:-1}"
if ! [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || [[ "$RETENTION_DAYS" -lt 1 ]]; then
    RETENTION_DAYS=1
fi
LOG_FILE="${LOG_FILE:-${SNAPSHOT_DIR}/cleanup-backups.log}"
DRY_RUN="${DRY_RUN:-0}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
log_error()   { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }

mkdir -p "$(dirname "$LOG_FILE")"

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

acquire_vm_backup_lock 14400 || exit 1

# Cutoff date string (YYYYMMDD) - files with date < this will be removed.
# RETENTION_DAYS=1 → cutoff=today (keep today only).
# RETENTION_DAYS=3 → cutoff=today-2 (keep last 3 calendar days).
CUTOFF_DATE=$(date -d "-$((RETENTION_DAYS - 1)) days" +%Y%m%d)

log_info "=========================================="
log_info "Cleanup Old Backups (keep last ${RETENTION_DAYS} days)"
log_info "Cutoff date: ${CUTOFF_DATE}"
[[ "$DRY_RUN" == "1" ]] && log_warning "DRY RUN MODE - no files will be deleted"
log_info "=========================================="

REMOVED=0
SKIPPED=0
ERRORS=0

# Remove a single file, respecting DRY_RUN
remove_file() {
    local file="$1"
    if [[ "$DRY_RUN" == "1" ]]; then
        log_warning "  [DRY RUN] Would remove: $file"
    else
        if rm -f "$file"; then
            log_success "  Removed: $file"
            (( REMOVED++ )) || true
        else
            log_error "  Failed to remove: $file"
            (( ERRORS++ )) || true
        fi
    fi
}

# Clean backup files in a directory matching a pattern.
# Extracts YYYYMMDD from filenames like *-20260320-000001* and compares to cutoff.
cleanup_dir() {
    local dir="$1"
    local pattern="$2"

    [[ -d "$dir" ]] || return 0

    while IFS= read -r -d '' file; do
        local basename
        basename="$(basename "$file")"

        # Extract 8-digit date from filename (YYYYMMDD)
        local date_str
        date_str=$(echo "$basename" | grep -oP '\d{8}(?=-\d{6})' | head -1)

        if [[ -z "$date_str" ]]; then
            log_warning "  Cannot parse date from: $file (skipping)"
            (( SKIPPED++ )) || true
            continue
        fi

        if [[ "$date_str" < "$CUTOFF_DATE" ]]; then
            local base
            base="$(backup_base_from_name "$basename")"
            if ! ensure_smb_mounted || ! smb_has_complete_backup "$base"; then
                log_warning "  KEEP local (no verified SMB copy): $file"
                (( SKIPPED++ )) || true
                continue
            fi
            remove_file "$file"
        fi
    done < <(find "$dir" -maxdepth 1 -name "$pattern" -print0 2>/dev/null)
}

log_info ""
log_info "--- ${SNAPSHOT_DIR} (faceid backups) ---"
cleanup_dir "$SNAPSHOT_DIR" "faceid-backup-*.xml"
cleanup_dir "$SNAPSHOT_DIR" "faceid-backup-*.qcow2"

log_info ""
log_info "--- ${SNAPSHOT_DIR} (wiseeye backups) ---"
cleanup_dir "$SNAPSHOT_DIR" "wiseeye-backup-*.xml"
cleanup_dir "$SNAPSHOT_DIR" "wiseeye-backup-*.qcow2"

log_info ""
log_info "--- ${SNAPSHOT_DIR} (fshare backups) ---"
cleanup_dir "$SNAPSHOT_DIR" "fshare-backup-*.xml"
cleanup_dir "$SNAPSHOT_DIR" "fshare-backup-*.qcow2"

log_info ""
log_info "--- ${SNAPSHOT_DIR} (kong-gateway backups) ---"
cleanup_dir "$SNAPSHOT_DIR" "kong-gateway-backup-*.xml"
cleanup_dir "$SNAPSHOT_DIR" "kong-gateway-backup-*.qcow2"

log_info ""
log_info "=========================================="
log_info "Summary: removed=${REMOVED}, skipped=${SKIPPED}, errors=${ERRORS}"
log_info "=========================================="

[[ "$ERRORS" -gt 0 ]] && exit 1 || exit 0
