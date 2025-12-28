#!/bin/bash

################################################################################
# Create WiseEye VM with Ubuntu 22.04 - Simple Interactive Method
# This creates the VM and opens VNC/console for manual installation
# VM Specs: 8 cores, 8GB RAM, 256GB storage
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

# VM Configuration
VM_NAME="wiseeye"
ISO_PATH="/mnt/data/iso/ubuntu-22.04.5-live-server-amd64.iso"
DISK_SIZE="256"
RAM="8192"
VCPUS="8"
DISK_PATH="/mnt/data/${VM_NAME}.qcow2"
BRIDGE_NAME="br0"

# Check ISO
if [ ! -f "$ISO_PATH" ]; then
    log_error "ISO not found: $ISO_PATH"
    exit 1
fi

# Check if VM exists
if virsh list --all | grep -q " $VM_NAME "; then
    log_warning "VM '$VM_NAME' already exists."
    read -p "Destroy and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        virsh destroy "$VM_NAME" 2>/dev/null || true
        virsh undefine "$VM_NAME" --remove-all-storage 2>/dev/null || true
        log_success "Removed existing VM"
    else
        exit 0
    fi
fi

echo ""
log_info "═══════════════════════════════════════════════════"
log_info "Creating WiseEye VM - Interactive Installation"
log_info "═══════════════════════════════════════════════════"
echo ""
echo "VM Configuration:"
echo "  • Name: $VM_NAME"
echo "  • RAM: 8GB"
echo "  • CPUs: 8 cores"
echo "  • Storage: 256GB"
echo "  • Network: Bridge (br0)"
echo ""
echo "Installation Settings (configure during install):"
echo "  • Username: ght"
echo "  • Password: 1"
echo "  • Hostname: wiseeye"
echo "  • SSH Server: Install OpenSSH"
echo ""
log_warning "The VM will start and you'll complete installation via console"
echo ""
read -p "Press Enter to create VM and start installation..."

log_info "Creating VM..."

virt-install \
    --name "$VM_NAME" \
    --ram "$RAM" \
    --vcpus "$VCPUS" \
    --disk path="$DISK_PATH",size="$DISK_SIZE",format=qcow2,bus=virtio \
    --cdrom "$ISO_PATH" \
    --os-variant ubuntu22.04 \
    --network bridge=$BRIDGE_NAME,model=virtio \
    --graphics none \
    --console pty,target_type=serial \
    --boot cdrom,hd

log_success "VM created! You are now in the installation console."
echo ""
log_info "Installation Steps:"
echo "  1. Select 'Install Ubuntu Server'"
echo "  2. Choose language: English"
echo "  3. Network: Accept DHCP (automatic)"
echo "  4. Storage: Use entire disk"
echo "  5. Profile setup:"
echo "     - Your name: ght"
echo "     - Server name: wiseeye"
echo "     - Username: ght"
echo "     - Password: 1"
echo "  6. Install OpenSSH server: YES"
echo "  7. No additional snaps needed"
echo "  8. Wait for installation to complete (~10 minutes)"
echo "  9. Reboot when prompted"
echo ""
log_info "After installation, configure SSH key manually"
