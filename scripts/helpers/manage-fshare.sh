#!/bin/bash

################################################################################
# FShare VM Management Helper Script
# Quick commands for managing the fshare VM
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VM_NAME="fshare"
IP_PRIMARY="10.168.1.104"
IP_SECONDARY="192.168.3.104"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_usage() {
    echo "FShare VM Management Helper"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  status      - Show VM status"
    echo "  start       - Start the VM"
    echo "  stop        - Stop the VM"
    echo "  restart     - Restart the VM"
    echo "  ssh         - SSH into VM (primary IP)"
    echo "  ssh2        - SSH into VM (secondary IP)"
    echo "  console     - Open VM console"
    echo "  ip          - Show VM IP addresses"
    echo "  java        - Check Java version"
    echo "  setup       - Run environment setup script"
    echo "  ping        - Test network connectivity"
    echo "  info        - Show detailed VM information"
    echo ""
}

case "${1:-}" in
    status)
        virsh list --all | grep -E "Id|$VM_NAME"
        ;;
    
    start)
        log_info "Starting $VM_NAME..."
        virsh start "$VM_NAME"
        log_success "VM started"
        ;;
    
    stop)
        log_info "Stopping $VM_NAME..."
        virsh shutdown "$VM_NAME"
        log_success "Shutdown signal sent"
        ;;
    
    restart)
        log_info "Restarting $VM_NAME..."
        virsh reboot "$VM_NAME"
        log_success "Reboot signal sent"
        ;;
    
    ssh)
        log_info "Connecting to $VM_NAME via primary IP..."
        ssh ght@$IP_PRIMARY
        ;;
    
    ssh2)
        log_info "Connecting to $VM_NAME via secondary IP..."
        ssh ght@$IP_SECONDARY
        ;;
    
    console)
        log_info "Opening console for $VM_NAME (Ctrl+] to exit)..."
        virsh console "$VM_NAME"
        ;;
    
    ip)
        echo "VM IP Addresses:"
        echo "  Primary:   $IP_PRIMARY (gateway: 10.168.1.1)"
        echo "  Secondary: $IP_SECONDARY (no gateway)"
        echo ""
        log_info "Testing connectivity..."
        if ping -c 1 -W 2 "$IP_PRIMARY" > /dev/null 2>&1; then
            log_success "Primary IP is reachable"
        else
            log_error "Primary IP not reachable"
        fi
        
        if ping -c 1 -W 2 "$IP_SECONDARY" > /dev/null 2>&1; then
            log_success "Secondary IP is reachable"
        else
            log_error "Secondary IP not reachable"
        fi
        ;;
    
    java)
        log_info "Checking Java version on $VM_NAME..."
        ssh -o StrictHostKeyChecking=no ght@$IP_PRIMARY "java -version 2>&1 | head -3"
        echo ""
        ssh -o StrictHostKeyChecking=no ght@$IP_PRIMARY "echo 'JAVA_HOME:' \$JAVA_HOME"
        ;;
    
    setup)
        log_info "Running environment setup script on $VM_NAME..."
        ssh -o StrictHostKeyChecking=no ght@$IP_PRIMARY "cd /home/ght/deploy/env/ubuntu-22.04 && ./install-env-22.04.sh"
        ;;
    
    ping)
        log_info "Testing network connectivity..."
        echo "Primary IP ($IP_PRIMARY):"
        ping -c 4 "$IP_PRIMARY" || log_error "Primary IP not responding"
        echo ""
        echo "Secondary IP ($IP_SECONDARY):"
        ping -c 4 "$IP_SECONDARY" || log_error "Secondary IP not responding"
        ;;
    
    info)
        echo "FShare VM Information:"
        echo "===================="
        echo ""
        virsh dominfo "$VM_NAME" 2>/dev/null || log_error "VM not found"
        echo ""
        echo "Network Configuration:"
        echo "  Primary:   $IP_PRIMARY/24 (gateway: 10.168.1.1)"
        echo "  Secondary: $IP_SECONDARY/24 (no gateway)"
        echo ""
        echo "Access:"
        echo "  ssh ght@$IP_PRIMARY"
        echo "  ssh ght@$IP_SECONDARY"
        echo ""
        ;;
    
    *)
        show_usage
        ;;
esac

