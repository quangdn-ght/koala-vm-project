#!/bin/bash

################################################################################
# Create WiseEye VM - FULLY AUTOMATED using Ubuntu 22.04 Cloud Image
# This script creates a ready-to-use VM with zero manual intervention
# VM Specs: 8 cores, 8GB RAM, 256GB storage
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
RAM="8192"
VCPUS="8"
DISK_SIZE="256G"
DISK_PATH="/mnt/data/${VM_NAME}.qcow2"
BRIDGE_NAME="br0"
CLOUD_IMG_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
CLOUD_IMG="/tmp/ubuntu-22.04-cloud.img"
CLOUD_INIT_DIR="/tmp/wiseeye-cloud-init-$$"

clear
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                                                                   ║"
echo "║     WiseEye VM - FULLY AUTOMATED Installation (Cloud Image)       ║"
echo "║                                                                   ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
log_info "Configuration: 8 cores, 8GB RAM, 256GB storage"
log_info "OS: Ubuntu 22.04 LTS (Cloud Image)"
log_info "Installation: 100% automated - ready in 2-3 minutes!"
echo ""

# Check if VM exists
if virsh list --all | grep -q " $VM_NAME "; then
    log_warning "VM '$VM_NAME' already exists. Removing..."
    virsh destroy "$VM_NAME" 2>/dev/null || true
    virsh undefine "$VM_NAME" --remove-all-storage 2>/dev/null || true
    rm -f "$DISK_PATH"
    log_success "Removed existing VM"
fi

# Download cloud image if not exists
if [ ! -f "$CLOUD_IMG" ]; then
    log_info "Downloading Ubuntu 22.04 cloud image..."
    wget -q --show-progress "$CLOUD_IMG_URL" -O "$CLOUD_IMG"
    log_success "Cloud image downloaded"
else
    log_info "Using cached cloud image"
fi

# Create VM disk from cloud image
log_info "Creating VM disk (256GB)..."
sudo qemu-img create -f qcow2 -F qcow2 -b "$CLOUD_IMG" "$DISK_PATH" "$DISK_SIZE"
sudo qemu-img resize "$DISK_PATH" "$DISK_SIZE"
log_success "VM disk created"

# Create cloud-init configuration
log_info "Creating cloud-init configuration..."
rm -rf "$CLOUD_INIT_DIR"
mkdir -p "$CLOUD_INIT_DIR"

# Meta-data
cat > "$CLOUD_INIT_DIR/meta-data" << EOF
instance-id: wiseeye-001
local-hostname: wiseeye
EOF

# User-data with full configuration
cat > "$CLOUD_INIT_DIR/user-data" << 'EOF'
#cloud-config
hostname: wiseeye
fqdn: wiseeye.local
manage_etc_hosts: true

users:
  - name: ght
    gecos: GHT User
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin, sudo
    lock_passwd: false
    passwd: $6$Qow7zg7XtSATpkJU$W6PzC8MH7153Ido7w.IopTbwD89WuHp5TIWp/Vr3HULVXwwiGQHvxQkuIQfnmanTqywxaL9u.Ftg0megvnG0L/
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCXwnKDEoJ4FuCMwHmoSOxhBOsUaeEbaIQc9BR+5z4mMOHlmPz0I3b67uJaUZGjgWmbT4W+dXw59eRmIu43rqhr41FfIaA8NDPXkcUCQmyhhCzGxFF4tJ1Ar2KK/b/1VvqbDXIh7bzkyTFGRMRif1SxYZfZm4R1+Yr3bvJz6z80QVXHI9kI5pHFRnHdE3O3kt4xVJo9HnnoMhQ6RNo4euG3rojUpFCNtq1hbuSUw7YPY9c8qpvQ8mrOAeElIkW6sfWPBZHw/AWI5r2CaGAiMYs7iP8w/bnqCcBt32GAb7kbyH/cUMjjqG3VeGgFMgERfnd9CfFHiC1XJ2lViCW7i1SatPqFcDE22HPdGbn+/2Bjym9+KA6gqa7E2eBXInvLph9Vz0v5BQbiGrbaeUuWYZ5n68i3uPiHYANmEeArDu0wnPNqFn6PvFEB0kfzG66gYZnO2AOjIa1bMyqYDxZU6BXrQRGqZpUGlTgJtbqBldzj8hikvUQH+TDWlVRnTZ2CgYMqDw792PSmhY/NGvItJTbGqLhSJYk1JR/+3ETdxSog3SI7F5pl3JmoXXilHX+DGm1d8rLQm7ogB/7lE5Pm/y9debq4vgMhQ8qXHVhzOZjHFAAz9w5qq1X7x0Kq6OGWPVx3iBIXJuyCfueEor4UsUrx8GdumBO8vViRQFd/l5wRRw== ght@ght-faceid-server

ssh_pwauth: true
disable_root: true

packages:
  - qemu-guest-agent
  - openssh-server
  - curl
  - wget
  - git
  - vim
  - net-tools
  - htop
  - build-essential

runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - mkdir -p /home/ght/deploy
  - chown -R ght:ght /home/ght/deploy
  - timedatectl set-timezone UTC

package_update: true
package_upgrade: true

power_state:
  mode: reboot
  timeout: 300
  condition: true
EOF

# Network config for DHCP
cat > "$CLOUD_INIT_DIR/network-config" << EOF
version: 2
ethernets:
  enp1s0:
    dhcp4: true
EOF

# Create cloud-init ISO
log_info "Creating cloud-init ISO..."
CLOUD_INIT_ISO="/tmp/wiseeye-cidata-$$.iso"

if command -v genisoimage &> /dev/null; then
    genisoimage -output "$CLOUD_INIT_ISO" -volid cidata -joliet -rock \
        "$CLOUD_INIT_DIR/user-data" "$CLOUD_INIT_DIR/meta-data" "$CLOUD_INIT_DIR/network-config" 2>/dev/null
else
    sudo apt-get install -y genisoimage -qq
    genisoimage -output "$CLOUD_INIT_ISO" -volid cidata -joliet -rock \
        "$CLOUD_INIT_DIR/user-data" "$CLOUD_INIT_DIR/meta-data" "$CLOUD_INIT_DIR/network-config" 2>/dev/null
fi

log_success "Cloud-init ISO created"

# Create and start VM
log_info "Creating and starting VM..."

virt-install \
    --name "$VM_NAME" \
    --virt-type kvm \
    --memory "$RAM" \
    --vcpus "$VCPUS" \
    --boot hd,menu=on \
    --disk path="$DISK_PATH",device=disk,bus=virtio \
    --disk path="$CLOUD_INIT_ISO",device=cdrom \
    --os-variant ubuntu22.04 \
    --network bridge="$BRIDGE_NAME",model=virtio \
    --graphics none \
    --console pty,target_type=serial \
    --noautoconsole \
    --import

sleep 5

log_success "VM created and started!"

# Wait for VM to boot and get IP
log_info "Waiting for VM to boot and configure (this takes ~2 minutes)..."
echo ""

VM_MAC=$(virsh domiflist "$VM_NAME" | grep -oP '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
VM_IP=""

for i in {1..60}; do
    # Check if VM is running
    if ! virsh list --state-running | grep -q "$VM_NAME"; then
        echo -n "."
        sleep 3
        continue
    fi
    
    # Try to get IP
    VM_IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    
    if [ -z "$VM_IP" ] && [ -n "$VM_MAC" ]; then
        VM_IP=$(ip neigh | grep -i "$VM_MAC" | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    fi
    
    if [ -n "$VM_IP" ]; then
        echo ""
        log_success "VM IP detected: $VM_IP"
        break
    fi
    
    echo -n "."
    sleep 3
done

echo ""

if [ -z "$VM_IP" ]; then
    log_warning "Could not detect IP automatically"
    log_info "Find it manually: virsh domifaddr $VM_NAME"
else
    # Save IP for later use
    echo "$VM_IP" > /tmp/wiseeye-vm-ip.txt
    
    # Wait for SSH to be ready
    log_info "Waiting for SSH service to be ready..."
    SSH_READY=false
    
    for i in {1..30}; do
        if timeout 3 ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o BatchMode=yes ght@$VM_IP exit 2>/dev/null; then
            SSH_READY=true
            break
        fi
        echo -n "."
        sleep 5
    done
    
    echo ""
    
    if [ "$SSH_READY" = true ]; then
        log_success "SSH is ready!"
    else
        log_warning "SSH not responding yet. Wait a minute and try: ssh ght@$VM_IP"
    fi
fi

# Cleanup
rm -rf "$CLOUD_INIT_DIR"

# Display summary
echo ""
log_success "╔════════════════════════════════════════════════════════════╗"
log_success "║     WiseEye VM Created Successfully - 100% Automated!      ║"
log_success "╚════════════════════════════════════════════════════════════╝"
echo ""
log_info "VM Details:"
echo "  • Name:     $VM_NAME"
echo "  • IP:       ${VM_IP:-Detecting...}"
echo "  • Username: ght"
echo "  • Password: 1"
echo "  • SSH Key:  Configured (passwordless)"
echo ""
log_info "Access VM:"
if [ -n "$VM_IP" ]; then
    echo "  ssh ght@$VM_IP"
else
    echo "  Get IP first: virsh domifaddr $VM_NAME"
fi
echo ""
log_info "Next Steps:"
echo "  1. Run post-install script to install Docker:"
echo "     ./scripts/helpers/post-install-wiseeye.sh"
echo ""
echo "  2. Or run complete deployment:"
echo "     ./scripts/helpers/deploy-wiseeye-complete.sh"
echo ""
log_info "VM Management:"
echo "  • Status:  virsh list --all"
echo "  • Start:   virsh start $VM_NAME"
echo "  • Stop:    virsh shutdown $VM_NAME"
echo "  • Console: virsh console $VM_NAME"
echo ""
log_success "Installation complete! 🚀"
