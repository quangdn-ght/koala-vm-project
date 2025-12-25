#!/bin/bash

################################################################################
# Automated KVM/QEMU + Cockpit Installation Script
# Target: Ubuntu Server 24.04 LTS (headless)
# Purpose: Install and configure virtualization with web-based management
################################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if script is run with sudo/root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run with sudo or as root"
        exit 1
    fi
}

# Get the actual user who invoked sudo
get_actual_user() {
    if [ -n "$SUDO_USER" ]; then
        echo "$SUDO_USER"
    else
        echo "$USER"
    fi
}

# Step 1: Update the system
update_system() {
    log_info "Step 1: Updating system packages..."
    if apt update && apt upgrade -y; then
        log_success "System packages updated successfully"
        return 0
    else
        log_error "Failed to update system packages"
        return 1
    fi
}

# Step 2: Install necessary packages
install_packages() {
    log_info "Step 2: Installing KVM/QEMU and Cockpit packages..."
    
    local packages=(
        "qemu-kvm"
        "libvirt-daemon-system"
        "libvirt-clients"
        "bridge-utils"
        "virtinst"
        "cpu-checker"
        "cockpit"
        "cockpit-machines"
    )
    
    if apt install -y "${packages[@]}"; then
        log_success "All packages installed successfully"
        return 0
    else
        log_error "Failed to install required packages"
        return 1
    fi
}

# Step 3: Check KVM hardware virtualization support
check_kvm_support() {
    log_info "Step 3: Checking KVM hardware virtualization support..."
    
    if ! command -v kvm-ok &> /dev/null; then
        log_error "kvm-ok command not found"
        return 1
    fi
    
    local kvm_output=$(kvm-ok 2>&1)
    echo "$kvm_output"
    
    if echo "$kvm_output" | grep -q "KVM acceleration can be used"; then
        log_success "KVM acceleration is available and can be used"
        return 0
    else
        log_error "KVM acceleration is NOT available"
        log_error "Please enable virtualization in BIOS/UEFI settings"
        return 1
    fi
}

# Step 4: Enable and start libvirt service
setup_libvirt() {
    log_info "Step 4: Enabling and starting libvirt service..."
    
    if systemctl enable --now libvirtd; then
        log_success "Libvirt service enabled and started"
        echo ""
        systemctl status libvirtd --no-pager
        echo ""
        return 0
    else
        log_error "Failed to enable/start libvirt service"
        return 1
    fi
}

# Step 5: Enable and start Cockpit service
setup_cockpit() {
    log_info "Step 5: Enabling and starting Cockpit service..."
    
    if systemctl enable --now cockpit.socket; then
        log_success "Cockpit service enabled and started"
        echo ""
        systemctl status cockpit.socket --no-pager
        echo ""
        return 0
    else
        log_error "Failed to enable/start Cockpit service"
        return 1
    fi
}

# Step 6: Add user to required groups
add_user_to_groups() {
    local actual_user=$(get_actual_user)
    log_info "Step 6: Adding user '$actual_user' to libvirt and kvm groups..."
    
    if adduser "$actual_user" libvirt && adduser "$actual_user" kvm; then
        log_success "User '$actual_user' added to libvirt and kvm groups"
        log_warning "Group changes will take effect after the user logs out and back in"
        log_warning "Or run: newgrp libvirt && newgrp kvm"
        return 0
    else
        log_error "Failed to add user to groups"
        return 1
    fi
}

# Step 7: Verify Cockpit is listening
verify_cockpit_port() {
    log_info "Step 7: Verifying Cockpit is listening on port 9090..."
    
    sleep 2  # Give Cockpit a moment to fully start
    
    if ss -tuln | grep 9090; then
        log_success "Cockpit is listening on port 9090"
        return 0
    else
        log_warning "Port 9090 not detected. Cockpit may still be starting..."
        return 0  # Don't fail the entire script
    fi
}

# Step 8: Display access instructions
display_access_info() {
    log_info "Step 8: Displaying access instructions..."
    
    local server_ip=$(hostname -I | awk '{print $1}')
    local actual_user=$(get_actual_user)
    
    echo ""
    echo "========================================================================"
    echo -e "${GREEN}Access Cockpit Web Interface:${NC}"
    echo "========================================================================"
    echo "URL: https://${server_ip}:9090"
    echo "Username: ${actual_user}"
    echo "Password: [Your system user password]"
    echo ""
    echo "Available from your network at:"
    hostname -I | tr ' ' '\n' | grep -v '^$' | while read ip; do
        echo "  - https://${ip}:9090"
    done
    echo ""
    echo -e "${YELLOW}Note: Your browser will warn about a self-signed certificate.${NC}"
    echo "      This is normal. Accept the risk and continue."
    echo ""
    echo "The 'Virtual Machines' option will appear in the left menu."
    echo "========================================================================"
}

# Step 9: Print completion message
print_completion() {
    log_info "Step 9: Installation complete!"
    
    local server_ip=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "========================================================================"
    echo -e "${GREEN}KVM/QEMU + Cockpit installation completed successfully!${NC}"
    echo "========================================================================"
    echo "Access URL: https://${server_ip}:9090"
    echo ""
    echo "Next steps:"
    echo "  1. Log out and log back in (for group changes to take effect)"
    echo "  2. Open the URL in your browser"
    echo "  3. Accept the self-signed certificate warning"
    echo "  4. Log in with your system credentials"
    echo "  5. Click 'Virtual Machines' in the left menu"
    echo ""
    echo "You can now create and manage virtual machines through the web interface!"
    echo "========================================================================"
}

# Enable firewall rule for Cockpit (if UFW is active)
configure_firewall() {
    if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        log_info "UFW firewall detected. Opening port 9090..."
        if ufw allow 9090/tcp; then
            log_success "Firewall rule added for Cockpit (port 9090)"
        else
            log_warning "Failed to add firewall rule. You may need to manually allow port 9090"
        fi
    fi
}

# Main execution
main() {
    echo "========================================================================"
    echo "  Automated KVM/QEMU + Cockpit Installation"
    echo "  Target: Ubuntu Server 24.04 LTS"
    echo "========================================================================"
    echo ""
    
    # Check if running as root
    check_root
    
    # Execute steps sequentially
    update_system || exit 1
    echo ""
    
    install_packages || exit 1
    echo ""
    
    check_kvm_support || exit 1
    echo ""
    
    setup_libvirt || exit 1
    echo ""
    
    setup_cockpit || exit 1
    echo ""
    
    add_user_to_groups || exit 1
    echo ""
    
    configure_firewall
    echo ""
    
    verify_cockpit_port || exit 1
    echo ""
    
    display_access_info
    echo ""
    
    print_completion
    
    log_success "All steps completed successfully!"
}

# Run main function
main "$@"
