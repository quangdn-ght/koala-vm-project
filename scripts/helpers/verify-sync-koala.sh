#!/bin/bash

################################################################################
# Verify Sync Koala Docker Compose Health on FaceID VM
# Quick health check script for the deployed service
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
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

VM_NAME="faceid"
VM_IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | grep -v '127.0.0.1' | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)

if [ -z "$VM_IP" ]; then
    VM_MAC=$(virsh domiflist "$VM_NAME" 2>/dev/null | grep -oP '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
    VM_IP=$(ip neigh | grep -i "$VM_MAC" | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
fi

if [ -z "$VM_IP" ]; then
    log_error "Could not find VM IP address"
    exit 1
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Sync Koala Health Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

log_info "FaceID VM: $VM_IP"
echo ""

# Check container status
log_info "Checking container status..."
CONTAINER_STATUS=$(ssh koala@$VM_IP "docker ps --filter name=sync_koala --format '{{.Status}}'")
if echo "$CONTAINER_STATUS" | grep -q "Up"; then
    log_success "Container is running"
    echo "    Status: $CONTAINER_STATUS"
else
    log_error "Container is not running"
    exit 1
fi
echo ""

# Check MySQL connectivity
log_info "Checking MySQL connectivity (127.0.0.1:3306)..."
if ssh koala@$VM_IP "timeout 2 bash -c '</dev/tcp/127.0.0.1/3306' 2>/dev/null"; then
    log_success "MySQL is accessible"
else
    log_error "MySQL is not accessible"
fi

# Check Redis connectivity
log_info "Checking Redis connectivity (127.0.0.1:6379)..."
if ssh koala@$VM_IP "timeout 2 bash -c '</dev/tcp/127.0.0.1/6379' 2>/dev/null"; then
    log_success "Redis is accessible"
else
    log_error "Redis is not accessible"
fi

# Check application port
log_info "Checking application port (127.0.0.1:5609)..."
if ssh koala@$VM_IP "timeout 2 bash -c '</dev/tcp/127.0.0.1/5609' 2>/dev/null"; then
    log_success "Application port 5609 is open"
else
    log_error "Application port 5609 is not accessible"
fi
echo ""

# Check logs for errors
log_info "Checking recent logs for errors..."
LOGS=$(ssh koala@$VM_IP "docker-compose -f /home/koala/sync_koala/docker-compose.yml logs --tail=5 2>&1")
if echo "$LOGS" | grep -qi "error\|failed\|exception" | grep -v "GET /health"; then
    log_error "Found errors in logs"
    echo "$LOGS"
else
    log_success "No critical errors in recent logs"
fi
echo ""

# Show MySQL connection status from logs
log_info "MySQL connection status from logs..."
MYSQL_STATUS=$(ssh koala@$VM_IP "docker-compose -f /home/koala/sync_koala/docker-compose.yml logs 2>&1 | grep -i 'mysql' | tail -3")
if echo "$MYSQL_STATUS" | grep -q "successful"; then
    log_success "MySQL connection confirmed"
    echo "$MYSQL_STATUS" | grep "successful" | head -1
else
    echo "$MYSQL_STATUS"
fi
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Health Check Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
log_info "Management Commands:"
echo "  ssh koala@$VM_IP"
echo "  cd /home/koala/sync_koala"
echo "  docker-compose ps              # Check status"
echo "  docker-compose logs -f         # Follow logs"
echo "  docker-compose restart         # Restart service"
echo ""
