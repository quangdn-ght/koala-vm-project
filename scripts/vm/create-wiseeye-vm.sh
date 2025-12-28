#!/bin/bash

################################################################################
# Create WiseEye VM with Ubuntu 22.04 - Fully Automated
# This script creates a KVM virtual machine with unattended installation
# VM Specs: 8 cores, 8GB RAM, 256GB storage
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# VM Configuration
VM_NAME="wiseeye"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ISO_PATH="/mnt/data/iso/ubuntu-22.04.5-live-server-amd64.iso"
PRESEED_PATH="$PROJECT_ROOT/config/wiseeye-preseed.cfg"
DISK_SIZE="256"  # GB
RAM="8192"       # MB (8GB)
VCPUS="8"
DISK_PATH="/mnt/data/${VM_NAME}.qcow2"
WEB_SERVER_PORT="8001"
BRIDGE_NAME="br0"  # Bridge interface for physical LAN

# Check if ISO exists
if [ ! -f "$ISO_PATH" ]; then
    log_error "ISO file not found: $ISO_PATH"
    log_info "Please ensure the ISO is available at /mnt/data/iso/ubuntu-22.04.5-live-server-amd64.iso"
    exit 1
fi

# Check if preseed file exists
if [ ! -f "$PRESEED_PATH" ]; then
    log_error "Preseed file not found: $PRESEED_PATH"
    exit 1
fi

# Check if VM already exists
if virsh list --all | grep -q "$VM_NAME"; then
    log_warning "VM '$VM_NAME' already exists."
    read -p "Do you want to destroy and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Destroying and undefining existing VM..."
        virsh destroy "$VM_NAME" 2>/dev/null || true
        virsh undefine "$VM_NAME" --remove-all-storage 2>/dev/null || true
        log_success "Removed existing VM"
    else
        log_info "Exiting without changes"
        exit 0
    fi
fi

log_info "Creating VM '$VM_NAME' with Ubuntu 22.04 (Manual Installation Required)..."
log_info "Configuration:"
echo "  - Name: $VM_NAME"
echo "  - RAM: ${RAM}MB (8GB)"
echo "  - CPUs: $VCPUS"
echo "  - Disk: ${DISK_SIZE}GB (stored on /mnt/data)"
echo "  - Network: Bridge ($BRIDGE_NAME) - Physical LAN DHCP"
echo "  - ISO: $ISO_PATH"
echo "  - Installation: Semi-automated (minimal interaction needed)"
echo "  - Default User: ght"
echo "  - Default Password: \"1\""
echo ""
log_warning "Ubuntu 22.04 live server requires interactive installation"
log_info "You'll need to complete installation manually via console"

# Start a temporary web server to serve preseed file
log_info "Starting temporary web server for preseed file..."
cd "$(dirname "$PRESEED_PATH")"
python3 -m http.server $WEB_SERVER_PORT > /dev/null 2>&1 &
WEB_SERVER_PID=$!
sleep 2

# Get host IP for preseed URL (use bridge IP if available)
if ip addr show "$BRIDGE_NAME" &>/dev/null; then
    HOST_IP=$(ip addr show "$BRIDGE_NAME" | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
else
    HOST_IP=$(hostname -I | awk '{print $1}')
fi
PRESEED_URL="http://${HOST_IP}:${WEB_SERVER_PORT}/wiseeye-preseed.cfg"

log_info "Preseed URL: $PRESEED_URL"

# Cleanup function
cleanup() {
    if [ -n "$WEB_SERVER_PID" ]; then
        log_info "Stopping temporary web server..."
        kill $WEB_SERVER_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Create the VM using virt-install with cdrom (Ubuntu 22.04 requires interactive install)
log_info "Creating VM with installation ISO..."
log_warning "You will need to connect to the console to complete installation"
log_info "Console command: virsh console $VM_NAME"
echo ""

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
    --noautoconsole

INSTALL_RESULT=$?

# Stop the web server
cleanup
trap - EXIT

if [ $INSTALL_RESULT -eq 0 ]; then
    log_success "VM '$VM_NAME' created and installed successfully!"
    echo ""
    log_success "============================================"
    log_success "Installation Complete!"
    log_success "============================================"
    echo ""
    log_info "VM Information:"
    virsh dominfo "$VM_NAME" 2>/dev/null || true
    echo ""
    log_info "Login Credentials:"
    echo "  - Username: ght"
    echo "  - Password: \"1\""
    echo "  - SSH: Passwordless (key-based authentication configured)"
    echo ""
    log_info "VM Management Commands:"
    echo "  - Start:      virsh start $VM_NAME"
    echo "  - Stop:       virsh shutdown $VM_NAME"
    echo "  - Force Stop: virsh destroy $VM_NAME"
    echo "  - Status:     virsh dominfo $VM_NAME"
    echo "  - Console:    virsh console $VM_NAME"
    echo "  - List All:   virsh list --all"
    echo ""
    
    # Try to get IP address (for bridged networks, use neighbor table)
    log_info "Waiting for VM to obtain IP address..."
    VM_MAC=$(virsh domiflist "$VM_NAME" | grep -oP '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
    VM_IP=""
    
    for i in {1..30}; do
        # Try virsh domifaddr first (works for NAT networks)
        VM_IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
        
        # If that fails, try neighbor table (works for bridged networks)
        if [ -z "$VM_IP" ] && [ -n "$VM_MAC" ]; then
            VM_IP=$(ip neigh | grep -i "$VM_MAC" | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
        fi
        
        if [ -n "$VM_IP" ]; then
            break
        fi
        sleep 2
    done
    
    if [ -n "$VM_IP" ]; then
        echo ""
        log_success "VM IP Address: $VM_IP"
        log_success "SSH Command: ssh ght@$VM_IP"
        echo ""
        
        # Save VM IP to a file for later use
        echo "$VM_IP" > /tmp/wiseeye-vm-ip.txt
        
        log_info "Testing SSH connectivity..."
        if timeout 5 ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes ght@$VM_IP exit 2>/dev/null; then
            log_success "SSH is accessible!"
            echo ""
            log_info "Next steps:"
            echo "  1. Run post-install script: $PROJECT_ROOT/scripts/helpers/post-install-wiseeye.sh"
            echo "  2. Or deploy everything: $PROJECT_ROOT/scripts/helpers/deploy-wiseeye-vm.sh"
        else
            log_warning "SSH may not be ready yet. Wait a few seconds and try: ssh ght@$VM_IP"
        fi
    else
        log_warning "Could not automatically detect VM IP address."
        log_info "Find it manually with: ip neigh | grep '$VM_MAC'"
    fi
else
    log_error "Failed to create VM or installation did not complete in time"
    log_info "You can check the installation progress with:"
    echo "  virsh console $VM_NAME"
    exit 1
fi
