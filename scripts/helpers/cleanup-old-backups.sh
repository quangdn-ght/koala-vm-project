#!/bin/bash

################################################################################
# Cleanup Old Backup Files
# Keeps only backup files from the last 7 days, removes older ones.
#
# Backup locations:
#   /mnt/data/              - faceid.faceid-backup-*, fshare.fshare-backup-*
#   /mnt/data/snapshot/     - faceid-backup-*, wiseeye-backup-*, fshare-backup-*
#   /mnt/data/vm-images/    - wiseeye-vm.wiseeye-backup-*, ubuntu-22.04-cloud.wiseeye-backup-*
################################################################################

set -euo pipefail

RETENTION_DAYS="${RETENTION_DAYS:-7}"
LOG_FILE="/mnt/data/snapshot/cleanup-backups.log"
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

# Cutoff date string (YYYYMMDD) - files with date < this will be removed
CUTOFF_DATE=$(date -d "-${RETENTION_DAYS} days" +%Y%m%d)

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
            remove_file "$file"
        fi
    done < <(find "$dir" -maxdepth 1 -name "$pattern" -print0 2>/dev/null)
}

log_info ""
log_info "--- /mnt/data (faceid backups) ---"
cleanup_dir "/mnt/data" "faceid.faceid-backup-*"

log_info ""
log_info "--- /mnt/data (fshare backups) ---"
cleanup_dir "/mnt/data" "fshare.fshare-backup-*"

log_info ""
log_info "--- /mnt/data/snapshot (faceid backups) ---"
cleanup_dir "/mnt/data/snapshot" "faceid-backup-*.xml"
cleanup_dir "/mnt/data/snapshot" "faceid-backup-*.qcow2"

log_info ""
log_info "--- /mnt/data/snapshot (wiseeye backups) ---"
cleanup_dir "/mnt/data/snapshot" "wiseeye-backup-*.xml"
cleanup_dir "/mnt/data/snapshot" "wiseeye-backup-*.qcow2"

log_info ""
log_info "--- /mnt/data/snapshot (fshare backups) ---"
cleanup_dir "/mnt/data/snapshot" "fshare-backup-*.xml"
cleanup_dir "/mnt/data/snapshot" "fshare-backup-*.qcow2"

log_info ""
log_info "--- /mnt/data/vm-images (wiseeye backups) ---"
cleanup_dir "/mnt/data/vm-images" "wiseeye-vm.wiseeye-backup-*"
cleanup_dir "/mnt/data/vm-images" "ubuntu-22.04-cloud.wiseeye-backup-*"

log_info ""
log_info "=========================================="
log_info "Summary: removed=${REMOVED}, skipped=${SKIPPED}, errors=${ERRORS}"
log_info "=========================================="

[[ "$ERRORS" -gt 0 ]] && exit 1 || exit 0
