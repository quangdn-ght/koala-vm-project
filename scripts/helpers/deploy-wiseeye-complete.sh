#!/bin/bash

################################################################################
# Complete WiseEye Deployment - Fully Automated
# Waits for VM, installs Docker, deploys application
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
log_info "  WiseEye Complete Deployment - Fully Automated"
log_info "═══════════════════════════════════════════════"
echo ""

# Wait for VM to be running
log_info "Step 1: Checking VM status..."
if ! virsh list --state-running | grep -q "$VM_NAME"; then
    log_error "VM '$VM_NAME' is not running"
    log_info "Start it with: virsh start $VM_NAME"
    exit 1
fi
log_success "VM is running"

# Get VM IP
log_info "Step 2: Getting VM IP address..."
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
    echo -n "."
    sleep 3
done

echo ""
if [ -z "$VM_IP" ]; then
    log_error "Could not detect VM IP"
    exit 1
fi
log_success "VM IP: $VM_IP"

# Wait for SSH
log_info "Step 3: Waiting for SSH..."
for i in {1..40}; do
    if timeout 3 ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o BatchMode=yes ${VM_USER}@${VM_IP} exit 2>/dev/null; then
        break
    fi
    echo -n "."
    sleep 5
done

echo ""
if ! timeout 3 ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no -o BatchMode=yes ${VM_USER}@${VM_IP} exit 2>/dev/null; then
    log_error "SSH not ready"
    exit 1
fi
log_success "SSH is ready"

# Install Docker
log_info "Step 4: Installing Docker..."
ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} 'bash -s' << 'ENDSSH'
# Install Docker
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sudo sh /tmp/get-docker.sh
sudo usermod -aG docker $USER
rm /tmp/get-docker.sh

# Install Docker Compose
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+' || echo "v2.23.0")
sudo curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
ENDSSH

log_success "Docker installed"

# Copy application files
log_info "Step 5: Deploying application..."
ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "mkdir -p /home/${VM_USER}/deploy/koala/wiseeye-sync"

scp -o StrictHostKeyChecking=no "$PROJECT_ROOT/koala/wiseeye-sync/docker-compose.yml" ${VM_USER}@${VM_IP}:/home/${VM_USER}/deploy/koala/wiseeye-sync/
scp -o StrictHostKeyChecking=no "$PROJECT_ROOT/koala/wiseeye-sync/.env" ${VM_USER}@${VM_IP}:/home/${VM_USER}/deploy/koala/wiseeye-sync/

log_success "Files copied"

# Start containers
log_info "Step 6: Starting containers..."
ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "cd /home/${VM_USER}/deploy/koala/wiseeye-sync && sudo /usr/local/bin/docker-compose up -d"

log_success "Containers started"

# Show status
echo ""
log_info "Checking container status..."
ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "cd /home/${VM_USER}/deploy/koala/wiseeye-sync && sudo /usr/local/bin/docker-compose ps"

echo ""
log_success "╔════════════════════════════════════════════════════════════╗"
log_success "║         WiseEye Deployment Complete!                       ║"
log_success "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "VM IP: $VM_IP"
echo "SSH: ssh ${VM_USER}@${VM_IP}"
echo "Frontend: http://${VM_IP}:3128"
echo "Backend: http://${VM_IP}:3003"
echo ""
