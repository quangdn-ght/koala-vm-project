#!/usr/bin/env bash

################################################################################
# VM Host Storage Optimization Script
# Purpose: Enable discard=unmap and perform offline qcow2 compaction
# Target: KVM/QEMU host running Ubuntu Server
# Run: On the host as regular user (will prompt for sudo when needed)
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Configuration
VM_NAME="${1:-faceid}"
DISK_PATH="/mnt/data/${VM_NAME}.qcow2"
BACKUP_SUFFIX="-precompact-$(date +%Y%m%d-%H%M%S)"
COMPACT_MODE="${2:-auto}"  # auto, discard-only, compact-only, full

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "Don't run this as root. Run as regular user (it will prompt for sudo when needed)"
    exit 1
fi

clear
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║      VM Host Storage Optimization Script                     ║"
echo "║      Enable Discard + Offline Compaction                     ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

log_info "Target VM: $VM_NAME"
log_info "Disk path: $DISK_PATH"
log_info "Mode: $COMPACT_MODE"
echo ""

# Verify VM exists
if ! virsh list --all | grep -q "$VM_NAME"; then
    log_error "VM '$VM_NAME' not found"
    log_info "Available VMs:"
    virsh list --all
    exit 1
fi

log_success "VM '$VM_NAME' found"
echo ""

# Function to enable discard in libvirt XML
enable_discard() {
    log_info "═══ Enabling Discard/UNMAP in VM Configuration ═══"
    echo ""
    
    # Get current XML configuration
    log_info "Checking current disk configuration..."
    # Use project directory for temp files instead of /tmp
    WORK_DIR="$SCRIPT_DIR/../../.vm-work"
    mkdir -p "$WORK_DIR"
    VM_XML=$(mktemp -p "$WORK_DIR" "${VM_NAME}-config.XXXXXX.xml")
    virsh dumpxml "$VM_NAME" > "$VM_XML"
    
    # Check if discard='unmap' is already present
    if grep -q "discard='unmap'" "$VM_XML"; then
        log_success "Discard='unmap' already enabled in VM configuration"
        rm "$VM_XML"
        return 0
    fi
    
    # Check disk driver type
    DISK_DRIVER=$(grep -oP "type='disk'.*?driver.*?type='\K[^']*" "$VM_XML" | head -1)
    DISK_BUS=$(grep -oP "<target dev='[^']*' bus='\K[^']*" "$VM_XML" | head -1)
    
    log_info "Current configuration:"
    echo "  Disk driver: ${DISK_DRIVER:-qcow2}"
    echo "  Bus type: ${DISK_BUS:-virtio}"
    echo ""
    
    # Check if bus is virtio (may need virtio-scsi for optimal discard)
    if [ "$DISK_BUS" = "virtio" ]; then
        log_warning "Disk uses 'virtio' bus (virtio-blk)"
        log_info "For optimal discard support, 'virtio-scsi' is recommended"
        log_info "Current setup should work, but consider migrating to virtio-scsi for production"
    fi
    
    log_info "Adding discard='unmap' to VM disk configuration..."
    
    # Use virsh edit to add discard='unmap' to driver element
    # Create a sed script to add discard='unmap' to the first disk driver
    EDIT_SCRIPT=$(mktemp)
    cat > "$EDIT_SCRIPT" << 'EOF'
# Find the first disk driver line and add discard='unmap'
/<disk type='file' device='disk'>/,/<\/disk>/ {
    s|<driver name='qemu' type='qcow2'/>|<driver name='qemu' type='qcow2' discard='unmap'/>|
    s|<driver name='qemu' type='qcow2' cache='[^']*'/>|<driver name='qemu' type='qcow2' cache='\1' discard='unmap'/>|
    s|<driver name='qemu' type='qcow2' io='[^']*'/>|<driver name='qemu' type='qcow2' io='\1' discard='unmap'/>|
    s|<driver name='qemu' type='qcow2' cache='[^']*' io='[^']*'/>|<driver name='qemu' type='qcow2' cache='\1' io='\2' discard='unmap'/>|
    s|<driver name='qemu' type='qcow2'>|<driver name='qemu' type='qcow2' discard='unmap'>|
}
EOF
    
    # Manual approach: shutdown VM, edit XML, redefine
    VM_WAS_RUNNING=false
    if virsh list --state-running | grep -q "$VM_NAME"; then
        VM_WAS_RUNNING=true
        log_info "VM is running. Shutdown required to modify configuration."
        read -p "Shutdown VM now to enable discard? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping discard enablement. VM will continue running."
            rm "$VM_XML" "$EDIT_SCRIPT"
            return 1
        fi
        
        log_info "Shutting down VM..."
        virsh shutdown "$VM_NAME" --mode acpi
        
        # Wait for shutdown
        for i in {1..60}; do
            if ! virsh list --state-running | grep -q "$VM_NAME"; then
                log_success "VM shut down successfully"
                break
            fi
            sleep 1
        done
        
        if virsh list --state-running | grep -q "$VM_NAME"; then
            log_error "VM shutdown timeout. Forcing stop..."
            virsh destroy "$VM_NAME"
        fi
    fi
    
    # Dump XML, modify it, redefine
    virsh dumpxml "$VM_NAME" > "${VM_XML}.orig"
    
    # Add discard='unmap' using sed
    sed -E "s|(<driver name='qemu' type='qcow2')([^/>]*)(/>)|\1\2 discard='unmap'\3|" "${VM_XML}.orig" > "${VM_XML}.new"
    
    # Verify the change was made
    if grep -q "discard='unmap'" "${VM_XML}.new"; then
        log_info "Modified XML with discard='unmap'"
        
        # Redefine the VM
        if virsh define "${VM_XML}.new"; then
            log_success "VM configuration updated with discard='unmap'"
            
            # Restart VM if it was running
            if [ "$VM_WAS_RUNNING" = true ]; then
                log_info "Starting VM..."
                virsh start "$VM_NAME"
                log_success "VM restarted"
            fi
        else
            log_error "Failed to redefine VM with new configuration"
            log_info "Original configuration preserved"
            rm "$VM_XML" "$EDIT_SCRIPT" "${VM_XML}.orig" "${VM_XML}.new"
            return 1
        fi
    else
        log_error "Failed to add discard='unmap' to XML"
        log_info "Manual edit required. Edit with: virsh edit $VM_NAME"
        log_info "Add: discard='unmap' to <driver> element"
        
        # Restart VM if needed
        if [ "$VM_WAS_RUNNING" = true ]; then
            virsh start "$VM_NAME"
        fi
    fi
    
    # Cleanup temp files
    rm -f "$VM_XML" "$EDIT_SCRIPT" "${VM_XML}.orig" "${VM_XML}.new"
    
    echo ""
    log_info "Verifying configuration..."
    if virsh dumpxml "$VM_NAME" | grep -q "discard='unmap'"; then
        log_success "✓ Discard='unmap' is now active"
        log_info "Guest VMs can now use fstrim to release space back to host"
    else
        log_warning "Could not verify discard='unmap' in configuration"
    fi
    
    echo ""
}

# Function to perform offline compaction
compact_disk() {
    log_info "═══ Performing Offline Disk Compaction ═══"
    echo ""
    
    # Check if disk exists
    if [ ! -f "$DISK_PATH" ]; then
        log_error "Disk file not found: $DISK_PATH"
        exit 1
    fi
    
    # Show current disk usage
    log_info "Current disk status:"
    echo "  Virtual size: $(ls -lh "$DISK_PATH" | awk '{print $5}')"
    echo "  Actual usage: $(du -h "$DISK_PATH" | awk '{print $1}')"
    echo ""
    
    # Check available space
    AVAILABLE_SPACE=$(df "$(dirname "$DISK_PATH")" | tail -1 | awk '{print $4}')
    AVAILABLE_GB=$((AVAILABLE_SPACE / 1024 / 1024))
    DISK_SIZE_GB=$(du -b "$DISK_PATH" | awk '{print int($1/1024/1024/1024)}')
    
    log_info "Available space: ${AVAILABLE_GB} GB"
    log_info "Disk size: ${DISK_SIZE_GB} GB"
    
    if [ $AVAILABLE_GB -lt $DISK_SIZE_GB ]; then
        log_error "Insufficient space for compaction"
        log_error "Need at least ${DISK_SIZE_GB} GB free"
        log_error "Available: ${AVAILABLE_GB} GB"
        exit 1
    fi
    
    log_success "Sufficient space available for compaction"
    echo ""
    
    # Confirm compaction
    log_warning "This will:"
    echo "  1. Shutdown the VM (if running)"
    echo "  2. Create a backup of current disk"
    echo "  3. Compact the disk (takes 5-15 minutes)"
    echo "  4. Replace old disk with compacted version"
    echo "  5. Restart the VM"
    echo ""
    
    read -p "Proceed with compaction? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Compaction cancelled by user"
        return 1
    fi
    
    echo ""
    
    # Step 1: Shutdown VM if running
    VM_WAS_RUNNING=false
    if virsh list --state-running | grep -q "$VM_NAME"; then
        VM_WAS_RUNNING=true
        log_info "Shutting down VM '$VM_NAME'..."
        virsh shutdown "$VM_NAME" --mode acpi
        
        # Wait for graceful shutdown
        log_info "Waiting for graceful shutdown (max 60 seconds)..."
        for i in {1..60}; do
            if ! virsh list --state-running | grep -q "$VM_NAME"; then
                log_success "VM shut down gracefully"
                break
            fi
            sleep 1
        done
        
        # Force stop if still running
        if virsh list --state-running | grep -q "$VM_NAME"; then
            log_warning "Graceful shutdown timeout, forcing stop..."
            virsh destroy "$VM_NAME"
        fi
        
        sleep 2
    else
        log_info "VM is already stopped"
    fi
    
    # Step 2: Create backup
    BACKUP_PATH="${DISK_PATH}${BACKUP_SUFFIX}"
    log_info "Creating backup: $BACKUP_PATH"
    sudo cp "$DISK_PATH" "$BACKUP_PATH"
    log_success "Backup created"
    echo ""
    
    # Step 3: Compact the disk
    COMPACT_PATH="${DISK_PATH}.compact-temp"
    log_info "Starting disk compaction..."
    log_info "Source: $DISK_PATH"
    log_info "Target: $COMPACT_PATH"
    log_warning "This may take 5-15 minutes depending on disk size..."
    echo ""
    
    START_TIME=$(date +%s)
    
    # Perform compaction with progress
    if sudo qemu-img convert -f qcow2 -O qcow2 -p "$DISK_PATH" "$COMPACT_PATH"; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        
        echo ""
        log_success "Compaction completed in ${DURATION} seconds"
        
        # Show size comparison
        OLD_SIZE=$(du -h "$DISK_PATH" | awk '{print $1}')
        NEW_SIZE=$(du -h "$COMPACT_PATH" | awk '{print $1}')
        
        echo ""
        log_info "Size comparison:"
        echo "  Old disk: $OLD_SIZE"
        echo "  New disk: $NEW_SIZE"
        
        # Calculate savings
        OLD_BYTES=$(du -b "$DISK_PATH" | awk '{print $1}')
        NEW_BYTES=$(du -b "$COMPACT_PATH" | awk '{print $1}')
        SAVED_BYTES=$((OLD_BYTES - NEW_BYTES))
        SAVED_GB=$((SAVED_BYTES / 1024 / 1024 / 1024))
        
        if [ $SAVED_BYTES -gt 0 ]; then
            echo -e "  ${GREEN}Saved:    ${SAVED_GB} GB${NC}"
        else
            echo "  Saved:    Negligible (disk was already optimal)"
        fi
        echo ""
        
        # Step 4: Replace old disk
        log_info "Replacing old disk with compacted version..."
        sudo mv "$DISK_PATH" "${DISK_PATH}.old"
        sudo mv "$COMPACT_PATH" "$DISK_PATH"
        sudo chown libvirt-qemu:kvm "$DISK_PATH"
        log_success "Disk replaced"
        echo ""
        
        # Verify with qemu-img info
        log_info "Verifying compacted disk..."
        sudo qemu-img info "$DISK_PATH"
        echo ""
        
    else
        log_error "Compaction failed"
        log_info "Restoring backup..."
        sudo mv "$BACKUP_PATH" "$DISK_PATH"
        log_success "Backup restored"
        
        # Restart VM if it was running
        if [ "$VM_WAS_RUNNING" = true ]; then
            log_info "Restarting VM..."
            virsh start "$VM_NAME"
        fi
        
        exit 1
    fi
    
    # Step 5: Restart VM if it was running
    if [ "$VM_WAS_RUNNING" = true ]; then
        log_info "Starting VM '$VM_NAME'..."
        virsh start "$VM_NAME"
        sleep 5
        log_success "VM started"
        
        # Wait for VM to be accessible
        log_info "Waiting for VM to become accessible..."
        VM_IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
        
        if [ -n "$VM_IP" ]; then
            for i in {1..30}; do
                if ping -c 1 -W 2 "$VM_IP" > /dev/null 2>&1; then
                    log_success "VM is accessible: $VM_IP"
                    break
                fi
                sleep 2
            done
        fi
    fi
    
    echo ""
    log_success "Compaction completed successfully"
    log_info "Backup files created:"
    echo "  • ${DISK_PATH}.old (can be removed after verification)"
    echo "  • $BACKUP_PATH (can be removed after verification)"
    echo ""
    log_info "To remove backups after verification:"
    echo "  sudo rm ${DISK_PATH}.old"
    echo "  sudo rm $BACKUP_PATH"
    echo ""
}

# Main execution logic
case "$COMPACT_MODE" in
    discard-only)
        enable_discard
        ;;
    compact-only)
        compact_disk
        ;;
    full)
        enable_discard
        echo ""
        compact_disk
        ;;
    auto|*)
        log_info "Running in AUTO mode"
        log_info "This will enable discard and optionally compact"
        echo ""
        
        # Always try to enable discard
        enable_discard
        
        echo ""
        log_info "Discard configuration complete"
        echo ""
        
        # Ask about compaction
        log_info "Would you like to perform disk compaction now?"
        log_warning "This will shutdown the VM temporarily (5-15 minutes)"
        echo ""
        read -p "Perform compaction? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            compact_disk
        else
            log_info "Skipping compaction. Run later with:"
            log_info "  bash $0 $VM_NAME compact-only"
        fi
        ;;
esac

# Final summary
echo ""
log_success "╔════════════════════════════════════════════════════════════╗"
log_success "║          Host Optimization Configuration Complete          ║"
log_success "╚════════════════════════════════════════════════════════════╝"
echo ""

log_info "Next Steps:"
echo ""
echo "  1. Run guest optimization script inside VM:"
echo "     ssh koala@10.168.1.55"
echo "     sudo bash /home/koala/optimize-vm-guest.sh"
echo ""
echo "  2. Test TRIM functionality (inside VM):"
echo "     sudo fstrim -av"
echo ""
echo "  3. Schedule automated compaction (optional):"
echo "     Add to crontab for monthly execution during low-load hours:"
echo "     0 2 1 * * bash $0 $VM_NAME compact-only >> /var/log/vm-compact.log 2>&1"
echo ""

log_info "Documentation:"
echo "  • Verify discard: virsh dumpxml $VM_NAME | grep discard"
echo "  • Check disk: sudo qemu-img info $DISK_PATH"
echo "  • Monitor space: watch -n 60 'du -h $DISK_PATH'"
echo ""

log_success "Host optimization script completed! 🚀"
