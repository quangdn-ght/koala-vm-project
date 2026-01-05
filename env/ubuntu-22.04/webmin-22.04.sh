#!/bin/bash

################################################################################
# Webmin Installation Script for Ubuntu 22.04/24.04 LTS
# Author: System Administrator
# Date: October 2025
# Description: Automated Webmin installation using official repository method
################################################################################

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print section headers
print_header() {
    echo ""
    print_message "$BLUE" "========================================="
    print_message "$BLUE" "$1"
    print_message "$BLUE" "========================================="
}

# Function to check if command was successful
check_status() {
    if [ $? -eq 0 ]; then
        print_message "$GREEN" "✓ $1"
    else
        print_message "$RED" "✗ $1"
        exit 1
    fi
}

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   print_message "$RED" "This script must be run as root (use sudo)"
   exit 1
fi

print_header "WEBMIN INSTALLATION SCRIPT"
print_message "$YELLOW" "This script will install Webmin on your Ubuntu system"
echo ""

# Step 1: Update system packages
print_header "Step 1: Updating System Packages"
apt update 2>&1 | tee /tmp/apt-update.log
UPDATE_EXIT_CODE=${PIPESTATUS[0]}

# Check if update had critical errors or just warnings
if grep -q "E: " /tmp/apt-update.log; then
    print_message "$YELLOW" "⚠ Warning: Some repository errors detected, but continuing..."
    print_message "$YELLOW" "You may want to fix these repository issues later:"
    grep "E: " /tmp/apt-update.log | while read line; do
        print_message "$YELLOW" "  $line"
    done
    echo ""
fi

# Only fail if apt update completely failed (exit code > 0 and no packages available)
if [ $UPDATE_EXIT_CODE -ne 0 ] && ! dpkg -l | grep -q "^ii"; then
    print_message "$RED" "✗ Critical error: Unable to update package lists"
    exit 1
else
    print_message "$GREEN" "✓ Package list updated (with some repository warnings)"
fi

read -p "Do you want to upgrade existing packages? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    apt upgrade -y
    if [ $? -eq 0 ]; then
        print_message "$GREEN" "✓ System packages upgraded"
    else
        print_message "$YELLOW" "⚠ Package upgrade had some issues, but continuing..."
    fi
fi

# Step 2: Install required dependencies
print_header "Step 2: Installing Required Dependencies"
apt install wget curl apt-transport-https software-properties-common gnupg2 -y
check_status "Dependencies installed"

# Step 3: Add Webmin GPG key and repository
print_header "Step 3: Setting Up Official Webmin Repository"
print_message "$YELLOW" "Adding Webmin GPG key..."

# Try the official setup script first
if curl -f -o /tmp/setup-repos.sh https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh 2>/dev/null; then
    print_message "$YELLOW" "Running official setup script..."
    bash /tmp/setup-repos.sh
    if [ $? -eq 0 ]; then
        print_message "$GREEN" "✓ Repository configured via official script"
        rm -f /tmp/setup-repos.sh
    else
        print_message "$YELLOW" "Official script failed, using manual method..."
        rm -f /tmp/setup-repos.sh
        
        # Manual method - Download and add GPG key
        wget -qO - https://download.webmin.com/jcameron-key.asc | gpg --dearmor | tee /usr/share/keyrings/webmin.gpg >/dev/null
        check_status "GPG key added"
        
        # Add repository with signed-by option
        echo "deb [signed-by=/usr/share/keyrings/webmin.gpg] https://download.webmin.com/download/repository sarge contrib" | tee /etc/apt/sources.list.d/webmin.list
        check_status "Webmin repository added"
    fi
else
    print_message "$YELLOW" "Official script not available, using manual method..."
    
    # Manual method - Download and add GPG key
    wget -qO - https://download.webmin.com/jcameron-key.asc | gpg --dearmor | tee /usr/share/keyrings/webmin.gpg >/dev/null
    check_status "GPG key added"
    
    # Add repository with signed-by option
    echo "deb [signed-by=/usr/share/keyrings/webmin.gpg] https://download.webmin.com/download/repository sarge contrib" | tee /etc/apt/sources.list.d/webmin.list
    check_status "Webmin repository added"
fi

# Step 4: Update package list with new repository
print_header "Step 4: Updating Package List"
apt update 2>&1 | tee /tmp/apt-update-webmin.log
UPDATE_EXIT_CODE=${PIPESTATUS[0]}

if grep -q "E: " /tmp/apt-update-webmin.log; then
    print_message "$YELLOW" "⚠ Warning: Some repository errors detected, but continuing..."
fi

if [ $UPDATE_EXIT_CODE -ne 0 ] && ! apt-cache search webmin &>/dev/null; then
    print_message "$RED" "✗ Critical error: Unable to update package lists"
    exit 1
else
    print_message "$GREEN" "✓ Package list updated with Webmin repository"
fi

# Verify Webmin package is available
print_message "$YELLOW" "Verifying Webmin package availability..."
if apt-cache search webmin | grep -q "^webmin "; then
    print_message "$GREEN" "✓ Webmin package found in repository"
else
    print_message "$RED" "✗ Webmin package not found!"
    print_message "$YELLOW" "Attempting alternative repository configuration..."
    
    # Alternative: Try older repository URL format
    echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list
    wget -qO - https://download.webmin.com/jcameron-key.asc | apt-key add -
    apt update
    
    if apt-cache search webmin | grep -q "^webmin "; then
        print_message "$GREEN" "✓ Webmin package found (alternative method)"
    else
        print_message "$RED" "Unable to locate Webmin package. Check your internet connection."
        print_message "$YELLOW" "Repository contents:"
        apt-cache search webmin
        exit 1
    fi
fi

# Step 5: Install Webmin
print_header "Step 5: Installing Webmin"
apt install webmin -y
check_status "Webmin installed successfully"

# Step 6: Check Webmin service status
print_header "Step 6: Verifying Webmin Service"
systemctl enable webmin
systemctl start webmin
sleep 2

if systemctl is-active --quiet webmin; then
    print_message "$GREEN" "✓ Webmin service is running"
else
    print_message "$RED" "✗ Webmin service is not running"
    print_message "$YELLOW" "Checking service status..."
    systemctl status webmin
fi

# Step 7: Configure firewall (if UFW is active)
print_header "Step 7: Configuring Firewall"
if command -v ufw &> /dev/null; then
    if ufw status | grep -q "Status: active"; then
        print_message "$YELLOW" "UFW firewall is active. Opening port 10000..."
        ufw allow 10000/tcp
        ufw reload
        check_status "Firewall configured - Port 10000 opened"
    else
        print_message "$YELLOW" "UFW firewall is not active. Skipping firewall configuration."
    fi
else
    print_message "$YELLOW" "UFW not found. Skipping firewall configuration."
fi

# Step 8: Get server IP address
print_header "Step 8: Installation Complete!"
SERVER_IP=$(hostname -I | awk '{print $1}')
if [ -z "$SERVER_IP" ]; then
    SERVER_IP="your-server-ip"
fi

print_message "$GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_message "$GREEN" "           WEBMIN INSTALLED SUCCESSFULLY!"
print_message "$GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_message "$BLUE" "Access Webmin at:"
print_message "$YELLOW" "  → https://$SERVER_IP:10000"
print_message "$YELLOW" "  → https://localhost:10000 (if local)"
echo ""
print_message "$BLUE" "Login Credentials:"
print_message "$YELLOW" "  Username: Your Ubuntu username (with sudo privileges)"
print_message "$YELLOW" "  Password: Your Ubuntu user password"
echo ""
print_message "$RED" "⚠ SECURITY WARNINGS:"
print_message "$YELLOW" "  • Your browser will show a security warning (self-signed certificate)"
print_message "$YELLOW" "  • This is normal - accept the certificate to continue"
print_message "$YELLOW" "  • ALWAYS use HTTPS (not HTTP) to access Webmin"
print_message "$YELLOW" "  • Consider installing a valid SSL certificate in production"
echo ""
print_message "$BLUE" "Post-Installation Recommendations:"
print_message "$YELLOW" "  1. Change default port 10000 to something less common"
print_message "$YELLOW" "  2. Enable two-factor authentication"
print_message "$YELLOW" "  3. Configure IP access restrictions"
print_message "$YELLOW" "  4. Install Let's Encrypt SSL certificate"
print_message "$YELLOW" "  5. Keep Webmin updated regularly"
echo ""
print_message "$GREEN" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Show service status
echo ""
print_message "$BLUE" "Current Webmin Service Status:"
systemctl status webmin --no-pager -l

# Display listening ports
echo ""
print_message "$BLUE" "Webmin is listening on:"
netstat -tulpn | grep :10000 || ss -tulpn | grep :10000

echo ""
print_message "$GREEN" "Installation script completed!"
print_message "$YELLOW" "For troubleshooting, check logs with: sudo journalctl -u webmin -n 50"
echo ""
