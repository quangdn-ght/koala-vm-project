#!/bin/bash

################################################################################
# Master Backup Script
# Backs up both WiseEye and FaceID VMs
################################################################################

# Check if running as root/sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script requires sudo privileges. Restarting with sudo..."
    exec sudo bash "$0" "$@"
fi

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="${SCRIPT_DIR}/scripts/helpers"

# Backup scripts
WISEEYE_BACKUP="${HELPERS_DIR}/backup-wiseeye-vm.sh"
FACEID_BACKUP="${HELPERS_DIR}/backup-faceid-vm.sh"

# Log file
LOG_FILE="/mnt/data/snapshot/backup-all.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Redirect output to log
exec > >(tee -a "$LOG_FILE") 2>&1

log_info "=========================================="
log_info "Starting Complete VM Backup Process"
log_info "=========================================="
log_info "Date: $(date '+%Y-%m-%d %H:%M:%S')"
log_info ""

# Check if backup scripts exist
if [[ ! -f "$WISEEYE_BACKUP" ]]; then
    log_error "WiseEye backup script not found: $WISEEYE_BACKUP"
    exit 1
fi

if [[ ! -f "$FACEID_BACKUP" ]]; then
    log_error "FaceID backup script not found: $FACEID_BACKUP"
    exit 1
fi

# Make sure scripts are executable
chmod +x "$WISEEYE_BACKUP"
chmod +x "$FACEID_BACKUP"

# Track success/failure
WISEEYE_SUCCESS=false
FACEID_SUCCESS=false

# Backup WiseEye VM
log_info "=========================================="
log_info "1/2: Starting WiseEye VM Backup"
log_info "=========================================="
if bash "$WISEEYE_BACKUP"; then
    log_success "✓ WiseEye VM backup completed successfully"
    WISEEYE_SUCCESS=true
else
    log_error "✗ WiseEye VM backup failed"
fi
echo ""

# Backup FaceID VM
log_info "=========================================="
log_info "2/2: Starting FaceID VM Backup"
log_info "=========================================="
if bash "$FACEID_BACKUP"; then
    log_success "✓ FaceID VM backup completed successfully"
    FACEID_SUCCESS=true
else
    log_error "✗ FaceID VM backup failed"
fi
echo ""

# Summary
log_info "=========================================="
log_info "Backup Summary"
log_info "=========================================="
log_info "WiseEye VM: $([ "$WISEEYE_SUCCESS" = true ] && echo -e "${GREEN}SUCCESS${NC}" || echo -e "${RED}FAILED${NC}")"
log_info "FaceID VM: $([ "$FACEID_SUCCESS" = true ] && echo -e "${GREEN}SUCCESS${NC}" || echo -e "${RED}FAILED${NC}")"
log_info "=========================================="

# Exit with error if any backup failed
if [ "$WISEEYE_SUCCESS" = true ] && [ "$FACEID_SUCCESS" = true ]; then
    log_success "All backups completed successfully!"
    exit 0
else
    log_error "One or more backups failed. Check the logs for details."
    exit 1
fi
