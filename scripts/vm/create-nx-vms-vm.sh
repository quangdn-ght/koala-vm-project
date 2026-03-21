#!/bin/bash

################################################################################
# Create NX-VMS VM - FULLY AUTOMATED using Ubuntu 24.04 Cloud Image
# This script creates a ready-to-use VM with zero manual intervention
# VM Specs: 8 cores, 8GB RAM, 100GB storage
# Network 1: 10.168.1.106/24 (gateway: 10.168.1.1)
# Network 2: 192.168.3.106/24 (no gateway)
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
VM_NAME="nx-vms"
RAM="8192"
VCPUS="8"
DISK_SIZE="100G"
DISK_PATH="/mnt/data/${VM_NAME}.qcow2"
BRIDGE_NAME="br0"
BRIDGE2_NAME="br1"
CLOUD_IMG_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
CLOUD_IMG="/mnt/data/ubuntu-22.04-cloud.img"
CLOUD_INIT_DIR="/tmp/nx-vms-cloud-init-$$"

# Network Configuration
NET1_IP="10.168.1.106"
NET1_GATEWAY="10.168.1.1"
NET1_NETMASK="24"
NET2_IP="192.168.3.106"
NET2_NETMASK="24"

clear
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                                                                   ║"
echo "║       NX-VMS VM - FULLY AUTOMATED Installation (Cloud Image)      ║"
echo "║                                                                   ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
log_info "Configuration: 8 cores, 8GB RAM, 100GB storage"
log_info "OS: Ubuntu 22.04 LTS (Cloud Image)"
log_info "Network 1: ${NET1_IP}/${NET1_NETMASK} (gateway: ${NET1_GATEWAY})"
log_info "Network 2: ${NET2_IP}/${NET2_NETMASK} (no gateway)"
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
log_info "Creating VM disk (100GB)..."
TMP_OVERLAY="/tmp/nx-vms-overlay-$$.qcow2"
sudo qemu-img create -f qcow2 -F qcow2 -b "$CLOUD_IMG" "$TMP_OVERLAY" "$DISK_SIZE"
sudo qemu-img resize "$TMP_OVERLAY" "$DISK_SIZE"
log_info "Flattening disk (removing backing file dependency)..."
sudo qemu-img convert -O qcow2 "$TMP_OVERLAY" "$DISK_PATH"
sudo rm -f "$TMP_OVERLAY"
sudo chown libvirt-qemu:kvm "$DISK_PATH"
log_success "VM disk created (standalone, no backing file)"

# Create cloud-init configuration
log_info "Creating cloud-init configuration..."
rm -rf "$CLOUD_INIT_DIR"
mkdir -p "$CLOUD_INIT_DIR"

# Meta-data
cat > "$CLOUD_INIT_DIR/meta-data" << EOF
instance-id: nx-vms-001
local-hostname: nx-vms
EOF

# User-data with full configuration
cat > "$CLOUD_INIT_DIR/user-data" << 'EOF'
#cloud-config
hostname: nx-vms
fqdn: nx-vms.local
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

# Network config with dual interfaces and static IPs
cat > "$CLOUD_INIT_DIR/network-config" << EOF
version: 2
ethernets:
  enp1s0:
    addresses:
      - ${NET1_IP}/${NET1_NETMASK}
    routes:
      - to: default
        via: ${NET1_GATEWAY}
    nameservers:
      addresses:
        - 8.8.8.8
        - 8.8.4.4
  enp2s0:
    addresses:
      - ${NET2_IP}/${NET2_NETMASK}
EOF

# Create cloud-init ISO
log_info "Creating cloud-init ISO..."
CLOUD_INIT_ISO="/tmp/nx-vms-cidata-$$.iso"

if command -v genisoimage &> /dev/null; then
    genisoimage -output "$CLOUD_INIT_ISO" -volid cidata -joliet -rock \
        "$CLOUD_INIT_DIR/user-data" "$CLOUD_INIT_DIR/meta-data" "$CLOUD_INIT_DIR/network-config" 2>/dev/null
else
    sudo apt-get install -y genisoimage -qq
    genisoimage -output "$CLOUD_INIT_ISO" -volid cidata -joliet -rock \
        "$CLOUD_INIT_DIR/user-data" "$CLOUD_INIT_DIR/meta-data" "$CLOUD_INIT_DIR/network-config" 2>/dev/null
fi

log_success "Cloud-init ISO created"

# Create and start VM with dual network interfaces
log_info "Creating and starting VM with dual network interfaces..."

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
    --network bridge="$BRIDGE2_NAME",model=virtio \
    --graphics none \
    --console pty,target_type=serial \
    --noautoconsole \
    --import

sleep 5

log_success "VM created and started!"

# Wait for VM to boot and get IP
log_info "Waiting for VM to boot and configure (this takes ~2 minutes)..."
echo ""

# Wait for VM to be running and cloud-init to complete
for i in {1..60}; do
    # Check if VM is running
    if virsh list --state-running | grep -q "$VM_NAME"; then
        # Try to ping the static IP
        if timeout 1 ping -c 1 "$NET1_IP" &>/dev/null; then
            echo ""
            log_success "VM is up and responding at $NET1_IP"
            break
        fi
    fi
    
    echo -n "."
    sleep 3
done

echo ""

# Wait for SSH to be ready
log_info "Waiting for SSH service to be ready..."
SSH_READY=false

for i in {1..30}; do
    if timeout 3 ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o BatchMode=yes ght@$NET1_IP exit 2>/dev/null; then
        SSH_READY=true
        break
    fi
    echo -n "."
    sleep 5
done

echo ""

if [ "$SSH_READY" = true ]; then
    log_success "SSH is ready!"
    
    # Run the install script
    log_info "Running post-installation script..."
    echo ""
    
    # Copy the install script to the VM
    scp -o StrictHostKeyChecking=no /home/ght/deploy/env/ubuntu-22.04/install-env-22.04.sh ght@$NET1_IP:/tmp/
    
    # Execute the script on the VM
    ssh -o StrictHostKeyChecking=no ght@$NET1_IP "bash /tmp/install-env-22.04.sh"
    
    log_success "Post-installation completed!"
else
    log_warning "SSH not responding yet. Wait a minute and try: ssh ght@$NET1_IP"
    log_info "You can run the install script manually after SSH is ready:"
    echo "  scp /home/ght/deploy/env/ubuntu-22.04/install-env-22.04.sh ght@$NET1_IP:/tmp/"
    echo "  ssh ght@$NET1_IP 'bash /tmp/install-env-22.04.sh'"
fi

# Cleanup
rm -rf "$CLOUD_INIT_DIR"
rm -f "$CLOUD_INIT_ISO"

# Display summary
echo ""
log_success "╔════════════════════════════════════════════════════════════╗"
log_success "║      NX-VMS VM Created Successfully - 100% Automated!      ║"
log_success "╚════════════════════════════════════════════════════════════╝"
echo ""
log_info "VM Details:"
echo "  • Name:       $VM_NAME"
echo "  • Network 1:  $NET1_IP (gateway: $NET1_GATEWAY)"
echo "  • Network 2:  $NET2_IP"
echo "  • Username:   ght"
echo "  • Password:   1"
echo "  • SSH Key:    Configured (passwordless)"
echo ""
log_info "Access VM:"
echo "  ssh ght@$NET1_IP"
echo ""
log_info "Verify Network Interfaces:"
echo "  ssh ght@$NET1_IP 'ip addr show'"
echo ""
log_info "VM Management:"
echo "  • Status:  virsh list --all"
echo "  • Start:   virsh start $VM_NAME"
echo "  • Stop:    virsh shutdown $VM_NAME"
echo "  • Console: virsh console $VM_NAME"
echo ""
log_success "Installation complete! 🚀"
