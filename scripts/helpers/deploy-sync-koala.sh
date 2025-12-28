#!/bin/bash

################################################################################
# Deploy Sync Koala Docker Compose to FaceID VM
# This script deploys the docker-compose.yml to the VM and verifies health
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

log_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

VM_NAME="faceid"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/koala/docker-compose.yml"
TARGET_DIR="/home/koala/sync_koala"

# Get VM IP
get_vm_ip() {
    local VM_MAC=$(virsh domiflist "$VM_NAME" 2>/dev/null | grep -oP '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
    
    if [ -z "$VM_MAC" ]; then
        return 1
    fi
    
    # Try virsh domifaddr
    local VM_IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | grep -v '127.0.0.1' | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    
    # Try neighbor table
    if [ -z "$VM_IP" ]; then
        VM_IP=$(ip neigh | grep -i "$VM_MAC" | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    fi
    
    echo "$VM_IP"
}

log_section "Deploy Sync Koala to FaceID VM"

# Check if compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    log_error "Docker compose file not found: $COMPOSE_FILE"
    exit 1
fi

# Get VM IP
log_info "Detecting FaceID VM IP address..."
VM_IP=$(get_vm_ip)

if [ -z "$VM_IP" ]; then
    log_error "Could not find IP address for VM '$VM_NAME'"
    log_error "Make sure the VM is running: virsh start $VM_NAME"
    exit 1
fi

log_success "VM IP: $VM_IP"

# Test SSH connectivity
log_info "Testing SSH connectivity..."
if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes koala@$VM_IP exit 2>/dev/null; then
    log_error "Cannot connect to VM via SSH"
    log_info "Try manually: ssh koala@$VM_IP"
    exit 1
fi
log_success "SSH connection successful"

# Create target directory on VM
log_section "Step 1: Creating Directory on VM"
ssh koala@$VM_IP "mkdir -p $TARGET_DIR"
log_success "Directory created: $TARGET_DIR"

# Copy docker-compose.yml to VM
log_section "Step 2: Copying docker-compose.yml"
scp -o StrictHostKeyChecking=no "$COMPOSE_FILE" koala@$VM_IP:$TARGET_DIR/
log_success "docker-compose.yml copied to VM"

# Verify MySQL is running
log_section "Step 3: Verifying MySQL Service"
log_info "Checking if MySQL is running on 127.0.0.1:3306..."

MYSQL_CHECK=$(ssh koala@$VM_IP "sudo netstat -tlnp | grep :3306 || sudo ss -tlnp | grep :3306 || echo 'not_found'")

if echo "$MYSQL_CHECK" | grep -q "not_found"; then
    log_error "MySQL is not running on port 3306"
    log_warning "Please install and start MySQL before running the container"
    log_info "Install MySQL: sudo apt-get install mysql-server"
    MYSQL_RUNNING=false
else
    log_success "MySQL is running on port 3306"
    MYSQL_RUNNING=true
fi

# Verify Redis is running
log_section "Step 4: Verifying Redis Service"
log_info "Checking if Redis is running on 127.0.0.1:6379..."

REDIS_CHECK=$(ssh koala@$VM_IP "sudo netstat -tlnp | grep :6379 || sudo ss -tlnp | grep :6379 || echo 'not_found'")

if echo "$REDIS_CHECK" | grep -q "not_found"; then
    log_error "Redis is not running on port 6379"
    log_warning "Please install and start Redis before running the container"
    log_info "Install Redis: sudo apt-get install redis-server"
    REDIS_RUNNING=false
else
    log_success "Redis is running on port 6379"
    REDIS_RUNNING=true
fi

# Warning if services not running
if [ "$MYSQL_RUNNING" = false ] || [ "$REDIS_RUNNING" = false ]; then
    log_warning "Required services are not running. The container may fail to start."
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deployment cancelled"
        exit 1
    fi
fi

# Pull Docker image
log_section "Step 5: Pulling Docker Image"
log_info "Pulling giahungtechnology/ght-sync-hrm:lastest..."
ssh koala@$VM_IP "cd $TARGET_DIR && docker-compose pull" || {
    log_warning "Failed to pull image, will try to start anyway"
}

# Stop existing containers
log_section "Step 6: Stopping Existing Containers"
ssh koala@$VM_IP "cd $TARGET_DIR && docker-compose down" 2>/dev/null || true
log_success "Stopped existing containers"

# Start docker-compose
log_section "Step 7: Starting Docker Compose"
log_info "Starting containers with host network mode..."
ssh koala@$VM_IP "cd $TARGET_DIR && docker-compose up -d"
log_success "Docker compose started"

# Wait for container to be ready
log_info "Waiting for container to be ready..."
sleep 5

# Check container status
log_section "Step 8: Verifying Container Health"

CONTAINER_STATUS=$(ssh koala@$VM_IP "cd $TARGET_DIR && docker-compose ps --format json 2>/dev/null || docker-compose ps")
log_info "Container Status:"
echo "$CONTAINER_STATUS"

# Check if container is running
if ssh koala@$VM_IP "cd $TARGET_DIR && docker-compose ps | grep -i 'up'"; then
    log_success "Container is running"
else
    log_error "Container is not running properly"
    log_info "Checking logs..."
    ssh koala@$VM_IP "cd $TARGET_DIR && docker-compose logs --tail=50"
    exit 1
fi

# Check container logs
log_section "Step 9: Container Logs (Last 20 lines)"
ssh koala@$VM_IP "cd $TARGET_DIR && docker-compose logs --tail=20"

# Test connectivity from container
log_section "Step 10: Testing Service Connectivity"

log_info "Testing MySQL connectivity from container..."
MYSQL_TEST=$(ssh koala@$VM_IP "docker exec \$(cd $TARGET_DIR && docker-compose ps -q) nc -zv 127.0.0.1 3306 2>&1 || echo 'failed'")
if echo "$MYSQL_TEST" | grep -q "succeeded\|open"; then
    log_success "MySQL connectivity: OK"
else
    log_error "MySQL connectivity: FAILED"
    echo "$MYSQL_TEST"
fi

log_info "Testing Redis connectivity from container..."
REDIS_TEST=$(ssh koala@$VM_IP "docker exec \$(cd $TARGET_DIR && docker-compose ps -q) nc -zv 127.0.0.1 6379 2>&1 || echo 'failed'")
if echo "$REDIS_TEST" | grep -q "succeeded\|open"; then
    log_success "Redis connectivity: OK"
else
    log_error "Redis connectivity: FAILED"
    echo "$REDIS_TEST"
fi

# Final summary
log_section "Deployment Summary"
log_success "Docker Compose deployed successfully!"
echo ""
log_info "Location: $TARGET_DIR on VM $VM_IP"
log_info "Service: thaiduongco-hrm"
log_info "Network Mode: host"
echo ""
log_info "Management Commands:"
echo "  ssh koala@$VM_IP"
echo "  cd $TARGET_DIR"
echo "  docker-compose ps        # Check status"
echo "  docker-compose logs -f   # View logs"
echo "  docker-compose restart   # Restart service"
echo "  docker-compose down      # Stop service"
echo "  docker-compose up -d     # Start service"
echo ""
log_info "Health Check:"
echo "  docker ps                # Check container status"
echo "  docker-compose logs      # View application logs"
echo ""
log_success "Deployment complete!"
