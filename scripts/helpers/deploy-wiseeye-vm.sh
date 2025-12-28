#!/bin/bash

################################################################################
# Complete WiseEye VM Deployment Orchestration Script
# This script orchestrates the entire VM creation and deployment process:
# 1. Creates the WiseEye VM with Ubuntu 22.04
# 2. Waits for VM to be ready
# 3. Runs post-install automation (Docker setup)
# 4. Clones deployment files
# 5. Deploys wiseeye-sync with docker-compose
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_section() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ $1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_header() {
    clear
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║             WiseEye VM Complete Deployment Script                ║"
    echo "║                                                                   ║"
    echo "║  • Create VM (8 cores, 8GB RAM, 256GB storage)                   ║"
    echo "║  • Install Docker & Docker Compose                                ║"
    echo "║  • Deploy wiseeye-sync application                                ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
}

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# VM Configuration
VM_NAME="wiseeye"
VM_USER="ght"

print_header

# Step 1: Create VM
print_section "Step 1: Creating WiseEye VM"
log_info "Running VM creation script..."

if [ ! -f "$PROJECT_ROOT/scripts/vm/create-wiseeye-vm.sh" ]; then
    log_error "VM creation script not found: $PROJECT_ROOT/scripts/vm/create-wiseeye-vm.sh"
    exit 1
fi

# Make sure script is executable
chmod +x "$PROJECT_ROOT/scripts/vm/create-wiseeye-vm.sh"

# Run VM creation script
if bash "$PROJECT_ROOT/scripts/vm/create-wiseeye-vm.sh"; then
    log_success "VM creation completed successfully"
else
    log_error "VM creation failed"
    exit 1
fi

# Get VM IP address
if [ -f /tmp/wiseeye-vm-ip.txt ]; then
    VM_IP=$(cat /tmp/wiseeye-vm-ip.txt)
    log_success "VM IP Address: $VM_IP"
else
    log_warning "VM IP not found in expected location"
    log_info "Attempting to detect VM IP..."
    
    VM_MAC=$(virsh domiflist "$VM_NAME" | grep -oP '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
    
    for i in {1..30}; do
        VM_IP=$(ip neigh | grep -i "$VM_MAC" | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
        if [ -n "$VM_IP" ]; then
            log_success "Detected VM IP: $VM_IP"
            break
        fi
        sleep 2
    done
    
    if [ -z "$VM_IP" ]; then
        log_error "Could not detect VM IP address"
        log_info "Please find it manually and run post-install script separately"
        exit 1
    fi
fi

# Step 2: Wait for SSH to be ready
print_section "Step 2: Waiting for SSH Access"
log_info "Waiting for VM to be fully accessible via SSH..."

SSH_READY=false
for i in {1..60}; do
    if timeout 5 ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes ${VM_USER}@${VM_IP} exit 2>/dev/null; then
        SSH_READY=true
        break
    fi
    echo -n "."
    sleep 5
done
echo ""

if [ "$SSH_READY" = false ]; then
    log_error "SSH connection to VM failed after timeout"
    log_info "VM IP: $VM_IP"
    log_info "Try manually: ssh ${VM_USER}@${VM_IP}"
    exit 1
fi

log_success "SSH connection to VM established"

# Step 3: Copy and run post-install script
print_section "Step 3: Running Post-Install Automation"
log_info "Copying post-install script to VM..."

# Copy post-install script
if scp -o StrictHostKeyChecking=no "$PROJECT_ROOT/scripts/helpers/post-install-wiseeye.sh" ${VM_USER}@${VM_IP}:/tmp/; then
    log_success "Post-install script copied to VM"
else
    log_error "Failed to copy post-install script"
    exit 1
fi

# Run post-install script on VM
log_info "Running post-install script on VM (this may take 5-10 minutes)..."
if ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "bash /tmp/post-install-wiseeye.sh"; then
    log_success "Post-install automation completed"
else
    log_error "Post-install script failed"
    exit 1
fi

# Step 4: Copy deployment files
print_section "Step 4: Deploying Application Files"
log_info "Creating deployment directory structure on VM..."

ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "mkdir -p /home/${VM_USER}/deploy/koala/wiseeye-sync"

log_info "Copying wiseeye-sync application files..."

# Copy docker-compose.yml
if scp -o StrictHostKeyChecking=no "$PROJECT_ROOT/koala/wiseeye-sync/docker-compose.yml" ${VM_USER}@${VM_IP}:/home/${VM_USER}/deploy/koala/wiseeye-sync/; then
    log_success "docker-compose.yml copied"
else
    log_error "Failed to copy docker-compose.yml"
    exit 1
fi

# Copy .env file
if scp -o StrictHostKeyChecking=no "$PROJECT_ROOT/koala/wiseeye-sync/.env" ${VM_USER}@${VM_IP}:/home/${VM_USER}/deploy/koala/wiseeye-sync/; then
    log_success ".env file copied"
else
    log_error "Failed to copy .env file"
    exit 1
fi

# Step 5: Deploy with docker-compose
print_section "Step 5: Starting Docker Containers"
log_info "Pulling Docker images and starting containers..."

# Run docker-compose on VM
if ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "cd /home/${VM_USER}/deploy/koala/wiseeye-sync && newgrp docker << EOF
docker-compose pull
docker-compose up -d
docker-compose ps
EOF"; then
    log_success "Docker containers started successfully"
else
    log_warning "Docker compose command may have had issues"
    log_info "Attempting alternative method..."
    
    # Alternative: use sudo
    if ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "cd /home/${VM_USER}/deploy/koala/wiseeye-sync && sudo docker-compose pull && sudo docker-compose up -d && sudo docker-compose ps"; then
        log_success "Docker containers started successfully (using sudo)"
    else
        log_error "Failed to start Docker containers"
        log_info "You may need to manually run:"
        log_info "  ssh ${VM_USER}@${VM_IP}"
        log_info "  cd /home/${VM_USER}/deploy/koala/wiseeye-sync"
        log_info "  docker-compose up -d"
        exit 1
    fi
fi

# Step 6: Verify deployment
print_section "Step 6: Verifying Deployment"
log_info "Checking container status..."

sleep 5

ssh -o StrictHostKeyChecking=no ${VM_USER}@${VM_IP} "cd /home/${VM_USER}/deploy/koala/wiseeye-sync && sudo docker-compose ps"

# Final summary
print_section "Deployment Complete!"
echo ""
log_success "╔══════════════════════════════════════════════════════════╗"
log_success "║          WiseEye VM Deployed Successfully!               ║"
log_success "╚══════════════════════════════════════════════════════════╝"
echo ""
echo -e "${BLUE}VM Information:${NC}"
echo "  • VM Name:     $VM_NAME"
echo "  • IP Address:  $VM_IP"
echo "  • Username:    $VM_USER"
echo "  • Password:    \"1\""
echo ""
echo -e "${BLUE}Access Methods:${NC}"
echo "  • SSH:         ssh ${VM_USER}@${VM_IP}"
echo "  • Console:     virsh console $VM_NAME"
echo ""
echo -e "${BLUE}Application Access:${NC}"
echo "  • Frontend:    http://${VM_IP}:3128"
echo "  • Backend:     http://${VM_IP}:3003"
echo "  • SQL Server:  ${VM_IP}:1433"
echo ""
echo -e "${BLUE}Useful Commands:${NC}"
echo "  • Check logs:      ssh ${VM_USER}@${VM_IP} 'cd ~/deploy/koala/wiseeye-sync && docker-compose logs -f'"
echo "  • Restart:         ssh ${VM_USER}@${VM_IP} 'cd ~/deploy/koala/wiseeye-sync && docker-compose restart'"
echo "  • Stop:            ssh ${VM_USER}@${VM_IP} 'cd ~/deploy/koala/wiseeye-sync && docker-compose down'"
echo "  • View status:     ssh ${VM_USER}@${VM_IP} 'cd ~/deploy/koala/wiseeye-sync && docker-compose ps'"
echo ""
echo -e "${BLUE}VM Management:${NC}"
echo "  • Start VM:        virsh start $VM_NAME"
echo "  • Stop VM:         virsh shutdown $VM_NAME"
echo "  • Force stop:      virsh destroy $VM_NAME"
echo "  • VM status:       virsh dominfo $VM_NAME"
echo ""
log_success "All steps completed successfully! 🚀"
echo ""
