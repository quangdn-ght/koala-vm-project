#!/bin/bash

################################################################################
# Create WiseEye VM with Ubuntu 22.04 - VNC Graphics Installation
# VM Specs: 8 cores, 8GB RAM, 256GB storage
# Access via VNC for easy graphical installation
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
    virsh destroy "$VM_NAME" 2>/dev/null || true
    virsh undefine "$VM_NAME" --remove-all-storage 2>/dev/null || true
    log_success "Removed existing VM"
fi

clear
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                                                                   ║"
echo "║         WiseEye VM Creation - VNC Graphical Installation          ║"
echo "║                                                                   ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo "VM Configuration:"
echo "  • Name:    wiseeye"
echo "  • RAM:     8 GB"
echo "  • CPUs:    8 cores"
echo "  • Storage: 256 GB"
echo "  • Network: Bridge (br0) - Physical LAN"
echo ""
echo "Installation Method:"
echo "  • VNC graphical installer (easy point-and-click)"
echo "  • Access via VNC viewer or virt-manager"
echo ""
echo "Installation Settings to Configure:"
echo "  ✓ Username: ght"
echo "  ✓ Password: 1"
echo "  ✓ Hostname: wiseeye"
echo "  ✓ Install OpenSSH Server: YES"
echo ""
log_info "The VM will start with VNC graphics enabled"
echo ""

# Get host IP for VNC connection info
HOST_IP=$(ip addr show "$BRIDGE_NAME" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
if [ -z "$HOST_IP" ]; then
    HOST_IP=$(hostname -I | awk '{print $1}')
fi

log_info "Creating VM with VNC graphics..."

virt-install \
    --name "$VM_NAME" \
    --ram "$RAM" \
    --vcpus "$VCPUS" \
    --disk path="$DISK_PATH",size="$DISK_SIZE",format=qcow2,bus=virtio \
    --cdrom "$ISO_PATH" \
    --os-variant ubuntu22.04 \
    --network bridge=$BRIDGE_NAME,model=virtio \
    --graphics vnc,listen=0.0.0.0,port=5901 \
    --noautoconsole &

VIRT_PID=$!
sleep 5

# Wait for VM to be created
log_info "Waiting for VM to start..."
for i in {1..20}; do
    if virsh list --state-running | grep -q "$VM_NAME"; then
        log_success "VM started successfully!"
        break
    fi
    sleep 1
done

# Get VNC port
VNC_PORT=$(virsh vncdisplay "$VM_NAME" 2>/dev/null | grep -oP ':\d+' | sed 's/://')
if [ -n "$VNC_PORT" ]; then
    ACTUAL_PORT=$((5900 + VNC_PORT))
else
    ACTUAL_PORT=5901
fi

echo ""
log_success "╔════════════════════════════════════════════════════════════╗"
log_success "║          VM Created Successfully!                          ║"
log_success "╚════════════════════════════════════════════════════════════╝"
echo ""
log_info "VM Status:"
virsh list --all | grep wiseeye
echo ""
log_info "═══════════════════════════════════════════════════════════════"
log_info "            VNC CONNECTION INFORMATION"
log_info "═══════════════════════════════════════════════════════════════"
echo ""
echo -e "${CYAN}Option 1: Using VNC Viewer${NC}"
echo "  • Download VNC Viewer: https://www.realvnc.com/download/viewer/"
echo "  • Connect to: ${HOST_IP}:${ACTUAL_PORT}"
echo "  • Or use display: ${HOST_IP}:${VNC_PORT}"
echo ""
echo -e "${CYAN}Option 2: Using virt-manager (if installed)${NC}"
echo "  • Run: virt-manager"
echo "  • Double-click 'wiseeye' VM"
echo "  • Or: virt-viewer wiseeye"
echo ""
echo -e "${CYAN}Option 3: SSH Tunnel + VNC (from your local machine)${NC}"
echo "  • From your laptop/desktop, run:"
echo "    ssh -L 5901:localhost:${ACTUAL_PORT} ght@${HOST_IP}"
echo "  • Then connect VNC to: localhost:5901"
echo ""
log_info "═══════════════════════════════════════════════════════════════"
echo ""
log_warning "INSTALLATION STEPS (in VNC):"
echo ""
echo "  1. Select: 'Install Ubuntu Server'"
echo "  2. Language: English"
echo "  3. Keyboard: English (US)"
echo "  4. Network: Accept DHCP (automatic)"
echo "  5. Proxy: Leave blank"
echo "  6. Mirror: Use default"
echo "  7. Storage: Use entire disk (default)"
echo "  8. Confirm storage changes"
echo "  9. Profile Setup:"
echo "     • Your name: ght"
echo "     • Server name: wiseeye"
echo "     • Username: ght"
echo "     • Password: 1"
echo "     • Confirm password: 1"
echo "  10. SSH Setup: Install OpenSSH server [X]"
echo "  11. Featured snaps: Skip (don't select any)"
echo "  12. Wait for installation (~10 minutes)"
echo "  13. Click 'Reboot Now'"
echo ""
log_info "After installation completes:"
echo "  • VM will reboot automatically"
echo "  • Get IP: virsh domifaddr wiseeye"
echo "  • SSH: ssh ght@<VM_IP>"
echo "  • Then run post-install script"
echo ""
log_success "Installation time: ~10-15 minutes"
echo ""
log_info "VM Management Commands:"
echo "  • Check status: virsh list --all"
echo "  • Get VNC port: virsh vncdisplay wiseeye"
echo "  • Stop VM: virsh destroy wiseeye"
echo "  • Start VM: virsh start wiseeye"
echo ""

wait $VIRT_PID 2>/dev/null || true

log_success "Setup complete! Connect via VNC to begin installation."
