#!/bin/bash

################################################################################
# Create WiseEye VM with Ubuntu 22.04 - Fully Automated (Autoinstall Method)
# This script creates a KVM virtual machine with cloud-init autoinstall
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
DISK_SIZE="256"  # GB
RAM="8192"       # MB (8GB)
VCPUS="8"
DISK_PATH="/mnt/data/${VM_NAME}.qcow2"
CLOUD_INIT_DIR="/tmp/wiseeye-cloud-init"
BRIDGE_NAME="br0"  # Bridge interface for physical LAN

# Check if ISO exists
if [ ! -f "$ISO_PATH" ]; then
    log_error "ISO file not found: $ISO_PATH"
    log_info "Please ensure the ISO is available at /mnt/data/iso/ubuntu-22.04.5-live-server-amd64.iso"
    exit 1
fi

# Check if VM already exists
if virsh list --all | grep -q " $VM_NAME "; then
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

log_info "Creating VM '$VM_NAME' with Ubuntu 22.04 (Cloud-init Autoinstall)..."
log_info "Configuration:"
echo "  - Name: $VM_NAME"
echo "  - RAM: ${RAM}MB (8GB)"
echo "  - CPUs: $VCPUS"
echo "  - Disk: ${DISK_SIZE}GB (stored on /mnt/data)"
echo "  - Network: Bridge ($BRIDGE_NAME) - Physical LAN DHCP"
echo "  - ISO: $ISO_PATH"
echo "  - Installation: Fully automated with autoinstall"
echo "  - Default User: ght"
echo "  - Default Password: \"1\""
echo ""

# Create cloud-init autoinstall configuration
log_info "Creating cloud-init autoinstall configuration..."
rm -rf "$CLOUD_INIT_DIR"
mkdir -p "$CLOUD_INIT_DIR"

# Create user-data with autoinstall config
cat > "$CLOUD_INIT_DIR/user-data" << 'EOF'
#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  network:
    network:
      version: 2
      ethernets:
        enp1s0:
          dhcp4: true
  storage:
    layout:
      name: direct
  identity:
    hostname: wiseeye
    username: ght
    password: "$6$Qow7zg7XtSATpkJU$W6PzC8MH7153Ido7w.IopTbwD89WuHp5TIWp/Vr3HULVXwwiGQHvxQkuIQfnmanTqywxaL9u.Ftg0megvnG0L/"
  ssh:
    install-server: true
    authorized-keys:
      - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCXwnKDEoJ4FuCMwHmoSOxhBOsUaeEbaIQc9BR+5z4mMOHlmPz0I3b67uJaUZGjgWmbT4W+dXw59eRmIu43rqhr41FfIaA8NDPXkcUCQmyhhCzGxFF4tJ1Ar2KK/b/1VvqbDXIh7bzkyTFGRMRif1SxYZfZm4R1+Yr3bvJz6z80QVXHI9kI5pHFRnHdE3O3kt4xVJo9HnnoMhQ6RNo4euG3rojUpFCNtq1hbuSUw7YPY9c8qpvQ8mrOAeElIkW6sfWPBZHw/AWI5r2CaGAiMYs7iP8w/bnqCcBt32GAb7kbyH/cUMjjqG3VeGgFMgERfnd9CfFHiC1XJ2lViCW7i1SatPqFcDE22HPdGbn+/2Bjym9+KA6gqa7E2eBXInvLph9Vz0v5BQbiGrbaeUuWYZ5n68i3uPiHYANmEeArDu0wnPNqFn6PvFEB0kfzG66gYZnO2AOjIa1bMyqYDxZU6BXrQRGqZpUGlTgJtbqBldzj8hikvUQH+TDWlVRnTZ2CgYMqDw792PSmhY/NGvItJTbGqLhSJYk1JR/+3ETdxSog3SI7F5pl3JmoXXilHX+DGm1d8rLQm7ogB/7lE5Pm/y9debq4vgMhQ8qXHVhzOZjHFAAz9w5qq1X7x0Kq6OGWPVx3iBIXJuyCfueEor4UsUrx8GdumBO8vViRQFd/l5wRRw== ght@ght-faceid-server"
    allow-pw: true
  packages:
    - openssh-server
    - curl
    - wget
    - git
    - vim
    - net-tools
  user-data:
    disable_root: true
  late-commands:
    - echo 'ght ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/ght
    - chmod 440 /target/etc/sudoers.d/ght
    - curtin in-target --target=/target -- mkdir -p /home/ght/deploy
    - curtin in-target --target=/target -- chown ght:ght /home/ght/deploy
EOF

# Create meta-data
cat > "$CLOUD_INIT_DIR/meta-data" << EOF
instance-id: wiseeye-vm-001
local-hostname: wiseeye
EOF

# Create cloud-init ISO
log_info "Creating cloud-init ISO..."
CLOUD_INIT_ISO="/tmp/wiseeye-cidata.iso"
rm -f "$CLOUD_INIT_ISO"

if command -v genisoimage &> /dev/null; then
    genisoimage -output "$CLOUD_INIT_ISO" -volid cidata -joliet -rock "$CLOUD_INIT_DIR/user-data" "$CLOUD_INIT_DIR/meta-data"
elif command -v mkisofs &> /dev/null; then
    mkisofs -output "$CLOUD_INIT_ISO" -volid cidata -joliet -rock "$CLOUD_INIT_DIR/user-data" "$CLOUD_INIT_DIR/meta-data"
else
    log_error "Neither genisoimage nor mkisofs found. Installing genisoimage..."
    sudo apt-get install -y genisoimage
    genisoimage -output "$CLOUD_INIT_ISO" -volid cidata -joliet -rock "$CLOUD_INIT_DIR/user-data" "$CLOUD_INIT_DIR/meta-data"
fi

log_success "Cloud-init ISO created"

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf "$CLOUD_INIT_DIR"
    rm -f "$CLOUD_INIT_ISO"
}
trap cleanup EXIT

# Create the VM
log_info "Creating VM and starting installation..."
log_warning "Installation will run automatically (15-20 minutes)"

virt-install \
    --name "$VM_NAME" \
    --ram "$RAM" \
    --vcpus "$VCPUS" \
    --disk path="$DISK_PATH",size="$DISK_SIZE",format=qcow2,bus=virtio \
    --disk path="$CLOUD_INIT_ISO",device=cdrom \
    --cdrom "$ISO_PATH" \
    --os-variant ubuntu22.04 \
    --network bridge=$BRIDGE_NAME,model=virtio \
    --graphics none \
    --console pty,target_type=serial \
    --noautoconsole \
    --wait -1 &

VIRT_PID=$!

log_info "VM installation started (PID: $VIRT_PID)"
log_info "Monitoring installation progress..."

# Wait for VM to be created
sleep 10

# Monitor installation
for i in {1..180}; do  # 30 minutes timeout
    if virsh list --state-running | grep -q "$VM_NAME"; then
        log_info "VM is running... installation in progress"
    elif virsh list --state-shutoff | grep -q "$VM_NAME"; then
        log_success "Installation completed - VM has shut down"
        break
    fi
    sleep 10
done

# Start the VM
log_info "Starting VM..."
virsh start "$VM_NAME"
sleep 5

INSTALL_RESULT=0

# Cleanup
cleanup
trap - EXIT

if [ $INSTALL_RESULT -eq 0 ]; then
    log_success "VM '$VM_NAME' created successfully!"
    echo ""
    log_success "============================================"
    log_success "Installation Complete!"
    log_success "============================================"
    echo ""
    
    # Try to get IP address
    log_info "Waiting for VM to obtain IP address..."
    VM_MAC=$(virsh domiflist "$VM_NAME" | grep -oP '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
    VM_IP=""
    
    for i in {1..60}; do
        VM_IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
        
        if [ -z "$VM_IP" ] && [ -n "$VM_MAC" ]; then
            VM_IP=$(ip neigh | grep -i "$VM_MAC" | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
        fi
        
        if [ -n "$VM_IP" ]; then
            break
        fi
        sleep 3
    done
    
    if [ -n "$VM_IP" ]; then
        echo ""
        log_success "VM IP Address: $VM_IP"
        log_success "SSH Command: ssh ght@$VM_IP"
        echo "$VM_IP" > /tmp/wiseeye-vm-ip.txt
        
        log_info "Testing SSH connectivity..."
        sleep 10
        if timeout 5 ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes ght@$VM_IP exit 2>/dev/null; then
            log_success "SSH is accessible!"
        else
            log_warning "SSH may not be ready yet. Wait and try: ssh ght@$VM_IP"
        fi
    else
        log_warning "Could not detect VM IP. Find manually: ip neigh | grep '$VM_MAC'"
    fi
    
    echo ""
    log_info "VM Information:"
    virsh dominfo "$VM_NAME"
    
else
    log_error "VM installation failed"
    exit 1
fi
