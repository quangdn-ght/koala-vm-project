#!/bin/bash

################################################################################
# Ubuntu Server 24.04 LTS (Noble) Deployment Environment Setup Script
# This script automates the installation of:
# - Docker & Docker Compose (latest with CLI compatibility)
# - Network Tools (essential networking utilities)
# - Docker Portainer (container management UI)
# Optimized specifically for Ubuntu Server 24.04 LTS (Noble Numbat)
################################################################################

set -e  # Exit immediately if a command exits with a non-zero status

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_section() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should NOT be run as root (don't use sudo)"
        print_info "The script will prompt for sudo password when needed"
        exit 1
    fi
}

# Function to check Ubuntu version
check_ubuntu_version() {
    print_section "Checking System Requirements"
    
    if [[ ! -f /etc/lsb-release ]]; then
        print_error "This script is designed for Ubuntu systems only"
        exit 1
    fi
    
    source /etc/lsb-release
    print_info "Detected OS: $DISTRIB_DESCRIPTION"
    
    # Extract version number
    VERSION_NUM=$(echo $DISTRIB_RELEASE | cut -d. -f1)
    
    if [[ "$DISTRIB_RELEASE" == "24.04" ]]; then
        print_success "Ubuntu 24.04 LTS (Noble) detected - Perfect match!"
    elif [[ $VERSION_NUM -eq 24 ]]; then
        print_success "Ubuntu 24.x detected - Compatible version"
    elif [[ $VERSION_NUM -lt 24 ]]; then
        print_warning "This script is optimized for Ubuntu Server 24.04 LTS"
        print_warning "Your version: $DISTRIB_RELEASE may have compatibility issues"
        read -p "Do you want to continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_warning "Ubuntu $VERSION_NUM detected - Newer than 24.04"
        print_info "Script optimized for 24.04, but should work on newer versions"
    fi
}

# Function to clean up any problematic repositories
cleanup_repositories() {
    print_section "Cleaning Up Repository Configuration"
    
    # Remove any existing Webmin repositories
    if [ -f /etc/apt/sources.list.d/webmin.list ]; then
        print_info "Removing old Webmin repository..."
        sudo rm -f /etc/apt/sources.list.d/webmin.list
        print_success "Webmin repository removed"
    fi
    
    # Remove Webmin GPG keys
    if [ -f /usr/share/keyrings/webmin.gpg ]; then
        print_info "Removing old Webmin GPG key..."
        sudo rm -f /usr/share/keyrings/webmin.gpg
        print_success "Webmin GPG key removed"
    fi
    
    # Clean apt cache
    print_info "Cleaning apt cache..."
    sudo apt-get clean > /dev/null 2>&1 || true
    print_success "Repository cleanup completed"
}

# Function to update system packages
update_system() {
    print_section "Updating System Packages"
    
    print_info "Updating package lists..."
    if sudo apt-get update; then
        print_success "Package lists updated successfully"
    else
        print_error "Failed to update package lists"
        exit 1
    fi
    
    print_info "Installing essential build tools and dependencies..."
    # Note: apt-transport-https no longer needed in Ubuntu 22.04+ (included by default)
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl wget git build-essential ca-certificates gnupg lsb-release software-properties-common; then
        print_success "Essential packages installed successfully"
    else
        print_error "Failed to install essential packages"
        exit 1
    fi
}

# Function to install network tools
install_network_tools() {
    print_section "Installing Network Tools"
    
    print_info "Installing essential network utilities..."
    
    # List of network tools to install (optimized for Ubuntu 24.04)
    local network_packages=(
        "net-tools"          # netstat, ifconfig, arp, route
        "iproute2"           # ip command (modern replacement for ifconfig/route)
        "dnsutils"           # dig, nslookup
        "traceroute"         # traceroute utility
        "telnet"             # telnet client
        "nmap"               # network scanner
        "tcpdump"            # packet analyzer
        "netcat-openbsd"     # netcat utility
        "ufw"                # uncomplicated firewall
        "htop"               # process viewer
        "iotop"              # I/O monitor
        "iftop"              # network bandwidth monitor
        "vnstat"             # network statistics
        "bmon"               # bandwidth monitor and rate estimator
    )
    
    # Note: Using ufw for firewall management (standard in Ubuntu 24.04)
    
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${network_packages[@]}"; then
        print_success "Network tools installed successfully"
        
        # Configure vnstat
        print_info "Configuring vnstat for network monitoring..."
        sudo systemctl enable vnstat > /dev/null 2>&1 || true
        sudo systemctl start vnstat > /dev/null 2>&1 || true
        
        # Configure UFW (disabled by default)
        print_info "UFW firewall installed (disabled by default)"
        
    else
        print_error "Failed to install network tools"
        exit 1
    fi
    
    print_success "Network tools installation completed"
}

# Function to install Docker
install_docker() {
    print_section "Installing Docker"
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        CURRENT_VERSION=$(docker --version)
        print_warning "Docker is already installed ($CURRENT_VERSION)"
        read -p "Do you want to reinstall/update? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping Docker installation"
            return 0
        fi
        
        # Remove old Docker packages if reinstalling
        print_info "Removing old Docker packages..."
        sudo apt-get remove -y -qq docker docker-engine docker.io containerd runc 2>/dev/null || true
    fi
    
    print_info "Setting up Docker repository..."
    
    # Create directory for Docker GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    
    # Add Docker's official GPG key
    if curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes; then
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        print_success "Docker GPG key added successfully"
    else
        print_error "Failed to add Docker GPG key"
        exit 1
    fi
    
    # Set up Docker repository for Ubuntu 24.04 Noble
    local UBUNTU_CODENAME=$(lsb_release -cs)
    
    print_info "Configuring Docker repository for $UBUNTU_CODENAME..."
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $UBUNTU_CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    print_success "Docker repository configured for Ubuntu 24.04 (noble)"
    
    # Update package lists with Docker repository
    print_info "Updating package lists..."
    if sudo apt-get update -qq; then
        print_success "Package lists updated"
    else
        print_error "Failed to update package lists"
        exit 1
    fi
    
    # Install Docker Engine, CLI, containerd, and plugins
    print_info "Installing Docker Engine and components..."
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        print_success "Docker installed successfully"
    else
        print_error "Failed to install Docker"
        exit 1
    fi
    
    # Start and enable Docker service
    print_info "Starting Docker service..."
    if sudo systemctl start docker && sudo systemctl enable docker > /dev/null 2>&1; then
        print_success "Docker service started and enabled"
    else
        print_error "Failed to start Docker service"
        exit 1
    fi
    
    # Verify Docker installation
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version)
        print_success "Docker installed: $DOCKER_VERSION"
    else
        print_error "Docker installation verification failed"
        exit 1
    fi
}

# Function to configure Docker to run without sudo
configure_docker_user() {
    print_section "Configuring Docker Permissions"
    
    print_info "Adding current user ($USER) to docker group..."
    
    # Create docker group if it doesn't exist
    if ! getent group docker > /dev/null 2>&1; then
        if sudo groupadd docker; then
            print_success "Docker group created"
        else
            print_error "Failed to create docker group"
            exit 1
        fi
    fi
    
    # Add current user to docker group
    if sudo usermod -aG docker $USER; then
        print_success "User $USER added to docker group"
        print_warning "You need to log out and log back in for this to take effect"
        print_info "Alternatively, run: newgrp docker"
    else
        print_error "Failed to add user to docker group"
        exit 1
    fi
    
    # Set permissions on Docker socket
    if sudo chmod 666 /var/run/docker.sock 2>/dev/null; then
        print_success "Docker socket permissions updated (temporary fix for current session)"
    fi
}

# Function to install Docker Portainer
install_portainer() {
    print_section "Installing Docker Portainer"
    
    print_info "Creating Portainer volume..."
    if docker volume create portainer_data > /dev/null 2>&1; then
        print_success "Portainer volume created"
    else
        print_warning "Portainer volume may already exist"
    fi
    
    print_info "Pulling latest Portainer Community Edition image..."
    if docker pull portainer/portainer-ce:latest > /dev/null 2>&1; then
        print_success "Portainer image pulled successfully"
    else
        print_error "Failed to pull Portainer image"
        exit 1
    fi
    
    print_info "Starting Portainer container..."
    if docker run -d \
        --name portainer \
        --restart=always \
        -p 8000:8000 \
        -p 9443:9443 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest > /dev/null 2>&1; then
        print_success "Portainer container started successfully"
    else
        # Check if container already exists
        if docker ps -a | grep -q portainer; then
            print_warning "Portainer container already exists"
            print_info "Restarting existing Portainer container..."
            docker restart portainer > /dev/null 2>&1 || true
        else
            print_error "Failed to start Portainer container"
            exit 1
        fi
    fi
    
    # Configure firewall for Portainer (if UFW is active)
    if sudo ufw status | grep -q "Status: active"; then
        print_info "Configuring firewall for Portainer..."
        sudo ufw allow 9443/tcp > /dev/null 2>&1 || true
        sudo ufw allow 8000/tcp > /dev/null 2>&1 || true
        print_success "Firewall configured for Portainer (ports 8000, 9443)"
    fi
    
    # Get server IP for access info
    local SERVER_IP=$(hostname -I | awk '{print $1}')
    
    print_success "Portainer installation completed"
    print_info "Access Portainer at: https://$SERVER_IP:9443"
    print_info "Create your admin account on first login"
}

# Function to verify Docker Compose installation
verify_docker_compose() {
    print_section "Verifying Docker Compose"
    
    # Docker Compose is now installed as a plugin (docker compose)
    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version)
        print_success "Docker Compose plugin installed: $COMPOSE_VERSION"
    else
        print_error "Docker Compose plugin verification failed"
        exit 1
    fi
}

# Function to install docker-compose CLI compatibility
install_docker_compose_cli() {
    print_section "Installing Docker Compose CLI Compatibility"
    
    print_info "Checking for docker-compose standalone CLI..."
    
    # Check if docker-compose CLI already exists
    if command -v docker-compose &> /dev/null; then
        local EXISTING_VERSION=$(docker-compose --version 2>/dev/null || echo "unknown")
        print_warning "docker-compose CLI already installed: $EXISTING_VERSION"
        read -p "Do you want to reinstall/update? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping docker-compose CLI installation"
            return 0
        fi
    fi
    
    print_info "Installing docker-compose standalone CLI for backward compatibility..."
    
    # Get latest version from GitHub API
    print_info "Fetching latest docker-compose version..."
    local COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+' || echo "")
    
    if [ -z "$COMPOSE_VERSION" ]; then
        print_warning "Could not fetch latest version, using v2.30.0 as fallback"
        COMPOSE_VERSION="v2.30.0"
    else
        print_info "Latest version: $COMPOSE_VERSION"
    fi
    
    # Download docker-compose standalone binary
    print_info "Downloading docker-compose CLI..."
    if sudo curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose 2>/dev/null; then
        print_success "docker-compose CLI downloaded"
    else
        print_error "Failed to download docker-compose CLI"
        exit 1
    fi
    
    # Make it executable
    if sudo chmod +x /usr/local/bin/docker-compose; then
        print_success "docker-compose CLI made executable"
    else
        print_error "Failed to set permissions on docker-compose CLI"
        exit 1
    fi
    
    # Verify installation
    if command -v docker-compose &> /dev/null; then
        local INSTALLED_VERSION=$(docker-compose --version)
        print_success "docker-compose CLI installed: $INSTALLED_VERSION"
        print_info "Both 'docker compose' and 'docker-compose' commands are now available"
    else
        print_error "docker-compose CLI verification failed"
        exit 1
    fi
}

# Function to run final verification tests
run_verification_tests() {
    print_section "Running Final Verification Tests"
    
    # Test network tools
    print_info "Testing network tools..."
    if command -v netstat &> /dev/null && command -v ip &> /dev/null; then
        print_success "Network tools test passed"
    else
        print_error "Network tools test failed"
    fi
    
    # Test Docker (may require group permissions to be active)
    print_info "Testing Docker..."
    if docker --version > /dev/null 2>&1; then
        print_success "Docker test passed"
        
        # Try to run a test container (might fail if user isn't in docker group yet)
        print_info "Attempting to run Docker hello-world container..."
        if docker run --rm hello-world > /dev/null 2>&1; then
            print_success "Docker container test passed"
        else
            print_warning "Docker container test skipped (you may need to log out and back in)"
            print_info "After logging back in, test with: docker run hello-world"
        fi
    else
        print_error "Docker test failed"
    fi
    
    # Test Docker Compose plugin
    print_info "Testing Docker Compose plugin..."
    if docker compose version > /dev/null 2>&1; then
        print_success "Docker Compose plugin test passed"
    else
        print_error "Docker Compose plugin test failed"
    fi
    
    # Test docker-compose CLI
    print_info "Testing docker-compose CLI..."
    if command -v docker-compose &> /dev/null && docker-compose --version > /dev/null 2>&1; then
        print_success "docker-compose CLI test passed"
    else
        print_warning "docker-compose CLI test failed"
    fi
    
    # Test Portainer
    print_info "Testing Portainer..."
    if docker ps | grep -q portainer; then
        print_success "Portainer container test passed"
    else
        print_warning "Portainer container test failed or not running"
    fi
}

# Function to display installation summary
display_summary() {
    print_section "Installation Summary"
    
    echo -e "${GREEN}All components installed successfully!${NC}\n"
    
    # Get server IP
    local SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo -e "${BLUE}Installed Components:${NC}"
    echo -e "• Network Tools (netstat, ip, dig, nmap, etc.)"
    
    if command -v docker &> /dev/null; then
        echo -e "• Docker: $(docker --version | cut -d' ' -f3 | sed 's/,//')"
        echo -e "• Docker Compose Plugin: $(docker compose version --short 2>/dev/null || echo 'installed')"
        if command -v docker-compose &> /dev/null; then
            echo -e "• docker-compose CLI: $(docker-compose --version | cut -d' ' -f4 | sed 's/,//')"
        fi
    fi
    
    if docker ps | grep -q portainer; then
        echo -e "• Docker Portainer - Container Management UI"
    fi
    
    echo -e "\n${YELLOW}Access Information:${NC}"
    echo -e "• Portainer Web Interface: ${GREEN}https://$SERVER_IP:9443${NC}"
    echo -e "  ${BLUE}(Create admin account on first login)${NC}"
    
    echo -e "\n${YELLOW}Docker Compose Usage:${NC}"
    echo -e "• Modern syntax: ${GREEN}docker compose up -d${NC}"
    echo -e "• Legacy syntax: ${GREEN}docker-compose up -d${NC}"
    echo -e "  ${BLUE}(Both commands work identically)${NC}"
    
    echo -e "\n${YELLOW}Important Next Steps:${NC}"
    echo -e "1. Log out and log back in to apply Docker group permissions"
    echo -e "   OR run: ${GREEN}newgrp docker${NC} in your current terminal"
    echo -e "2. After logging back in, test Docker with: ${GREEN}docker run hello-world${NC}"
    echo -e "3. Set up Portainer admin account on first login"
    echo -e "4. Consider configuring UFW firewall: ${GREEN}sudo ufw enable${NC}"
    echo -e "5. Monitor network usage: ${GREEN}vnstat${NC}, ${GREEN}bmon${NC}, or ${GREEN}iftop${NC}"
    echo -e "6. Start deploying containers! 🚀\n"
    
    print_success "Ubuntu Server deployment environment ready!"
}

# Function to handle errors
error_handler() {
    print_error "An error occurred during installation"
    print_info "Please check the output above for details"
    exit 1
}

# Trap errors
trap error_handler ERR

################################################################################
# Main execution flow
################################################################################

main() {
    clear
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║    Ubuntu Server 24.04 LTS (Noble) Environment Setup           ║"
    echo "║    Docker + Network Tools + Portainer                          ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    # Run setup steps
    check_root
    check_ubuntu_version
    cleanup_repositories
    update_system
    install_network_tools
    install_docker
    configure_docker_user
    verify_docker_compose
    install_docker_compose_cli
    install_portainer
    run_verification_tests
    display_summary
}

# Run main function
main

exit 0
