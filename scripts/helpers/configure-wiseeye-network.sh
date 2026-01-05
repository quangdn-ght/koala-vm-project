#!/bin/bash

################################################################################
# Configure WiseEye VM Network
# Sets up dual network interfaces with static IPs
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

VM_NAME="wiseeye"
VM_USER="ght"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo ""
log_info "═══════════════════════════════════════════════"
log_info "  Configure WiseEye VM Network"
log_info "═══════════════════════════════════════════════"
echo ""

# Try to find VM IP (temporary DHCP)
log_info "Finding VM IP..."
VM_IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)

if [ -z "$VM_IP" ]; then
    VM_MAC=$(virsh domiflist "$VM_NAME" | grep -oP '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
    VM_IP=$(ip neigh | grep -i "$VM_MAC" | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
fi

if [ -z "$VM_IP" ]; then
    log_error "Could not find VM IP. Please provide it:"
    read -p "VM IP: " VM_IP
fi

log_success "VM IP: $VM_IP"

# Test SSH connectivity
log_info "Testing SSH connection..."
if ! timeout 3 ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o BatchMode=yes ${VM_USER}@${VM_IP} exit 2>/dev/null; then
    log_error "Cannot connect to VM via SSH"
    log_info "Make sure SSH is installed and the VM is accessible"
    exit 1
fi
log_success "SSH connection OK"

# Get interface names
log_info "Detecting network interfaces..."
IFACE1=$(ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "ip -o link show | awk -F': ' '/^[0-9]: (en|eth)/{print \$2; exit}'")
IFACE2=$(ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "ip -o link show | awk -F': ' '/^[0-9]: (en|eth)/{print \$2}' | sed -n '2p'")

log_info "Primary interface: $IFACE1"
log_info "Secondary interface: $IFACE2"

# Create netplan configuration
log_info "Creating netplan configuration..."

NETPLAN_CONFIG="network:
  version: 2
  renderer: networkd
  ethernets:"

if [ -n "$IFACE1" ]; then
NETPLAN_CONFIG+="
    $IFACE1:
      addresses:
        - 10.168.1.56/24
      routes:
        - to: default
          via: 10.168.1.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4"
fi

if [ -n "$IFACE2" ]; then
NETPLAN_CONFIG+="
    $IFACE2:
      addresses:
        - 192.168.3.56/24"
fi

# Apply configuration
log_info "Applying network configuration..."
ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "sudo tee /etc/netplan/01-netcfg.yaml > /dev/null" << EOF
$NETPLAN_CONFIG
EOF

ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "sudo chmod 600 /etc/netplan/01-netcfg.yaml"
ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "sudo netplan apply"

log_success "Network configuration applied"

echo ""
log_info "Waiting for network to stabilize..."
sleep 5

echo ""
log_success "╔════════════════════════════════════════════════════════════╗"
log_success "║         Network Configuration Complete!                    ║"
log_success "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Network Configuration:"
echo "  Primary: $IFACE1 → 10.168.1.56/24 (gateway: 10.168.1.1)"
echo "  Secondary: $IFACE2 → 192.168.3.56/24"
echo ""
echo "Connect using: ssh ${VM_USER}@10.168.1.56"
echo ""
