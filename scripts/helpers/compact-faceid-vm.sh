#!/bin/bash

################################################################################
# Compact FaceID VM qcow2 File
# This script safely compacts the VM disk to reclaim deleted space
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

VM_NAME="faceid"
DISK_PATH="/mnt/data/${VM_NAME}.qcow2"
BACKUP_PATH="/mnt/data/${VM_NAME}-precompact-$(date +%Y%m%d-%H%M%S).qcow2"
COMPACT_PATH="/mnt/data/${VM_NAME}-compact-temp.qcow2"

clear
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║          FaceID VM Disk Compaction Tool                      ║"
echo "║          Reclaim ~121 GB of deleted space                    ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check if running as regular user
if [[ $EUID -eq 0 ]]; then
    log_error "Don't run this as root. Run as regular user (it will prompt for sudo when needed)"
    exit 1
fi

# Check if VM exists
if ! virsh list --all | grep -q "$VM_NAME"; then
    log_error "VM '$VM_NAME' not found"
    exit 1
fi

# Show current disk usage
log_info "Current Disk Usage:"
echo "  qcow2 file (virtual): $(ls -lh $DISK_PATH | awk '{print $5}')"
echo "  qcow2 file (actual):  $(du -h $DISK_PATH | awk '{print $1}')"
echo ""

log_warning "This process will:"
echo "  1. Stop the FaceID VM (services will be unavailable)"
echo "  2. Create a safety backup of the disk"
echo "  3. Compact the disk (this takes 10-15 minutes)"
echo "  4. Replace old disk with compacted version"
echo "  5. Restart the VM"
echo ""
log_warning "Required: ~90 GB free space in /mnt/data"
echo ""

# Check available space
AVAILABLE_SPACE=$(df /mnt/data | tail -1 | awk '{print $4}')
AVAILABLE_GB=$((AVAILABLE_SPACE / 1024 / 1024))
log_info "Available space in /mnt/data: ${AVAILABLE_GB} GB"

if [ $AVAILABLE_GB -lt 90 ]; then
    log_error "Insufficient space. Need at least 90 GB free in /mnt/data"
    log_info "Current free: ${AVAILABLE_GB} GB"
    exit 1
fi

read -p "Do you want to proceed with compaction? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    log_info "Aborted by user"
    exit 0
fi

echo ""
log_info "Starting compaction process..."
echo ""

# Step 1: Stop the VM
log_info "Step 1/5: Stopping VM '$VM_NAME'..."
if virsh list --state-running | grep -q "$VM_NAME"; then
    virsh shutdown "$VM_NAME"
    
    # Wait for graceful shutdown (max 60 seconds)
    log_info "Waiting for graceful shutdown (max 60 seconds)..."
    for i in {1..60}; do
        if ! virsh list --state-running | grep -q "$VM_NAME"; then
            log_success "VM stopped gracefully"
            break
        fi
        echo -n "."
        sleep 1
    done
    echo ""
    
    # Force stop if still running
    if virsh list --state-running | grep -q "$VM_NAME"; then
        log_warning "Graceful shutdown timed out, forcing stop..."
        virsh destroy "$VM_NAME"
    fi
else
    log_info "VM is already stopped"
fi

sleep 2
log_success "VM stopped"
echo ""

# Step 2: Create backup
log_info "Step 2/5: Creating safety backup..."
log_info "Backup: $BACKUP_PATH"
sudo cp "$DISK_PATH" "$BACKUP_PATH"
log_success "Backup created (you can delete this later if compaction succeeds)"
echo ""

# Step 3: Compact the disk
log_info "Step 3/5: Compacting disk (this takes 10-15 minutes)..."
log_info "Source: $DISK_PATH"
log_info "Temp:   $COMPACT_PATH"
echo ""
log_warning "Please wait... (progress shown below)"
echo ""

START_TIME=$(date +%s)
sudo qemu-img convert -O qcow2 -p "$DISK_PATH" "$COMPACT_PATH"
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
log_success "Compaction completed in ${DURATION} seconds"
echo ""

# Step 4: Show results and replace
log_info "Step 4/5: Comparing sizes..."
OLD_SIZE=$(du -h "$DISK_PATH" | awk '{print $1}')
NEW_SIZE=$(du -h "$COMPACT_PATH" | awk '{print $1}')
OLD_SIZE_BYTES=$(du -b "$DISK_PATH" | awk '{print $1}')
NEW_SIZE_BYTES=$(du -b "$COMPACT_PATH" | awk '{print $1}')
SAVED_BYTES=$((OLD_SIZE_BYTES - NEW_SIZE_BYTES))
SAVED_GB=$((SAVED_BYTES / 1024 / 1024 / 1024))

echo "  Old disk: $OLD_SIZE"
echo "  New disk: $NEW_SIZE"
echo -e "  ${GREEN}Saved:    ${SAVED_GB} GB${NC}"
echo ""

log_info "Replacing old disk with compacted version..."
sudo mv "$DISK_PATH" "$DISK_PATH.old"
sudo mv "$COMPACT_PATH" "$DISK_PATH"
sudo chown libvirt-qemu:kvm "$DISK_PATH"
log_success "Disk replaced"
echo ""

# Step 5: Start the VM
log_info "Step 5/5: Starting VM..."
virsh start "$VM_NAME"
sleep 5
log_success "VM started"
echo ""

# Wait for VM to boot
log_info "Waiting for VM to boot and become accessible..."
VM_IP="10.168.1.55"
for i in {1..30}; do
    if ping -c 1 -W 2 "$VM_IP" > /dev/null 2>&1; then
        echo ""
        log_success "VM is online: $VM_IP"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

# Verify SSH
log_info "Testing SSH connectivity..."
if timeout 5 ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes koala@$VM_IP exit 2>/dev/null; then
    log_success "SSH is accessible!"
else
    log_warning "SSH not responding yet. Wait a moment and try: ssh koala@$VM_IP"
fi

echo ""
log_success "╔════════════════════════════════════════════════════════════╗"
log_success "║          Compaction Completed Successfully!                ║"
log_success "╚════════════════════════════════════════════════════════════╝"
echo ""
log_info "Results:"
echo "  • Space saved: ${SAVED_GB} GB"
echo "  • Old disk kept as: $DISK_PATH.old"
echo "  • Backup created: $BACKUP_PATH"
echo ""
log_info "Cleanup (after verifying VM works correctly):"
echo "  sudo rm $DISK_PATH.old"
echo "  sudo rm $BACKUP_PATH"
echo ""
log_info "Verify VM:"
echo "  ./faceid-vm status"
echo "  ./faceid-vm ssh"
echo ""
log_success "Done! 🚀"
