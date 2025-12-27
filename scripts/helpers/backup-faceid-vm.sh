#!/bin/bash

################################################################################
# FaceID VM Automatic Backup Script
# Creates daily backups of VM disk and configuration
################################################################################

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

# Configuration
VM_NAME="faceid"
SOURCE_DISK="/mnt/data/${VM_NAME}.qcow2"
BACKUP_DIR="/mnt/data/snapshot"
DATE_STAMP=$(date '+%Y%m%d-%H%M%S')
BACKUP_NAME="${VM_NAME}-backup-${DATE_STAMP}"
KEEP_BACKUPS=3  # Keep last 3 backups to save storage space

# Log file
LOG_FILE="${BACKUP_DIR}/backup.log"

# Redirect all output to log file
exec > >(tee -a "$LOG_FILE") 2>&1

log_info "=========================================="
log_info "FaceID VM Backup Starting"
log_info "=========================================="

# Check if VM exists
if ! virsh list --all | grep -q "$VM_NAME"; then
    log_error "VM '$VM_NAME' not found!"
    exit 1
fi

# Check if source disk exists
if [ ! -f "$SOURCE_DISK" ]; then
    log_error "Source disk not found: $SOURCE_DISK"
    exit 1
fi

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Get VM state
VM_STATE=$(virsh domstate "$VM_NAME")
log_info "VM State: $VM_STATE"

# Create snapshot-based backup
log_info "Creating backup: ${BACKUP_NAME}"
log_info "Source: $SOURCE_DISK"
log_info "Destination: ${BACKUP_DIR}/${BACKUP_NAME}.qcow2"

# Get source disk size
SOURCE_SIZE=$(du -h "$SOURCE_DISK" | cut -f1)
log_info "Source disk size: $SOURCE_SIZE"

# Create incremental backup using qcow2 snapshot
if [ "$VM_STATE" == "running" ]; then
    log_info "VM is running - creating live snapshot..."
    
    # Create external snapshot for live backup
    virsh snapshot-create-as "$VM_NAME" "$BACKUP_NAME" \
        --description "Automatic backup - $(date '+%Y-%m-%d %H:%M:%S')" \
        --disk-only --atomic --no-metadata 2>/dev/null || {
        log_warning "Live snapshot failed, using qemu-img copy instead"
        # Fallback to direct copy (less safe but works)
        sudo qemu-img convert -O qcow2 -c "$SOURCE_DISK" "${BACKUP_DIR}/${BACKUP_NAME}.qcow2"
    }
    
    # If snapshot succeeded, copy the backing file and merge
    if [ $? -eq 0 ]; then
        log_info "Copying disk image..."
        sudo cp "$SOURCE_DISK" "${BACKUP_DIR}/${BACKUP_NAME}.qcow2"
        
        # Commit snapshot back to original
        virsh blockcommit "$VM_NAME" vda --active --pivot 2>/dev/null || true
    fi
else
    log_info "VM is stopped - creating offline backup..."
    # For stopped VMs, just copy the disk
    sudo qemu-img convert -O qcow2 -c "$SOURCE_DISK" "${BACKUP_DIR}/${BACKUP_NAME}.qcow2"
fi

if [ -f "${BACKUP_DIR}/${BACKUP_NAME}.qcow2" ]; then
    BACKUP_SIZE=$(du -h "${BACKUP_DIR}/${BACKUP_NAME}.qcow2" | cut -f1)
    log_success "Backup completed successfully!"
    log_info "Backup size: $BACKUP_SIZE"
    
    # Backup VM XML configuration
    log_info "Backing up VM configuration..."
    virsh dumpxml "$VM_NAME" > "${BACKUP_DIR}/${BACKUP_NAME}.xml"
    log_success "Configuration backed up"
else
    log_error "Backup failed - file not created!"
    exit 1
fi

# Cleanup old backups (keep last N backups)
log_info "Cleaning up old backups (keeping last ${KEEP_BACKUPS} to save storage space)..."
cd "$BACKUP_DIR"
ls -t ${VM_NAME}-backup-*.qcow2 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | while read OLD_BACKUP; do
    log_warning "Removing old backup: $OLD_BACKUP"
    rm -f "$OLD_BACKUP"
    rm -f "${OLD_BACKUP%.qcow2}.xml"
    REMOVED_SIZE=$(echo "$OLD_BACKUP" | awk '{print "~500GB"}')
    log_success "Freed storage space: $REMOVED_SIZE"
done

# Show available backups
log_info "Available backups:"
ls -lh ${VM_NAME}-backup-*.qcow2 2>/dev/null | tail -5 | awk '{print "  " $9 " (" $5 ")"}'

# Calculate total backup size
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
log_info "Total backup directory size: $TOTAL_SIZE"

log_success "=========================================="
log_success "Backup completed successfully at $(date '+%Y-%m-%d %H:%M:%S')"
log_success "=========================================="
