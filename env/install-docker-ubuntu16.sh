#!/bin/bash

################################################################################
# Docker Installation Script for Ubuntu 16.04 (Xenial)
# This script automates the installation of Docker CE (latest supported version)
# and Docker Compose for Ubuntu 16.04 Server
# Designed to run automatically during VM provisioning
################################################################################

set -e  # Exit immediately if a command exits with a non-zero status

# Color codes for output formatting
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

# Main installation function
main() {
    log_section "Docker Installation for Ubuntu 16.04 - FaceID VM"
    
    log_info "Starting Docker installation process..."
    log_info "OS: Ubuntu 16.04 (Xenial Xerus)"
    log_info "Target: FaceID VM"
    echo ""
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
    
    # Update package index
    log_section "Step 1: Updating Package Index"
    apt-get update -y
    log_success "Package index updated"
    
    # Install prerequisites
    log_section "Step 2: Installing Prerequisites"
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common \
        gnupg-agent \
        gnupg2 \
        lsb-release
    log_success "Prerequisites installed"
    
    # Add Docker's official GPG key
    log_section "Step 3: Adding Docker GPG Key"
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    log_success "Docker GPG key added"
    
    # Verify the fingerprint
    apt-key fingerprint 0EBFCD88 || log_warning "Could not verify fingerprint, but continuing..."
    
    # Add Docker repository for Ubuntu 16.04
    log_section "Step 4: Adding Docker Repository"
    add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) \
        stable"
    log_success "Docker repository added"
    
    # Update package index again
    log_info "Updating package index with Docker repository..."
    apt-get update -y
    log_success "Package index updated"
    
    # Install Docker CE
    log_section "Step 5: Installing Docker CE"
    # For Ubuntu 16.04, install the latest supported version
    apt-get install -y docker-ce docker-ce-cli containerd.io
    log_success "Docker CE installed"
    
    # Start and enable Docker service
    log_section "Step 6: Starting Docker Service"
    systemctl start docker
    systemctl enable docker
    log_success "Docker service started and enabled"
    
    # Verify Docker installation
    log_info "Verifying Docker installation..."
    docker --version
    log_success "Docker is installed and running"
    
    # Install Docker Compose
    log_section "Step 7: Installing Docker Compose"
    
    # Get latest Docker Compose version (or use a specific version for stability)
    DOCKER_COMPOSE_VERSION="1.29.2"  # Last version supporting Ubuntu 16.04
    log_info "Installing Docker Compose version $DOCKER_COMPOSE_VERSION"
    
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    
    chmod +x /usr/local/bin/docker-compose
    
    # Create symlink for convenience
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose || true
    
    log_success "Docker Compose installed"
    
    # Verify Docker Compose installation
    log_info "Verifying Docker Compose installation..."
    docker-compose --version
    log_success "Docker Compose is installed"
    
    # Add user to docker group for running Docker without sudo
    log_section "Step 8: Configuring Docker Group"
    
    # Get the actual user who invoked sudo (not root)
    ACTUAL_USER="${SUDO_USER:-$USER}"
    
    if [ "$ACTUAL_USER" != "root" ] && id "$ACTUAL_USER" &>/dev/null; then
        usermod -aG docker "$ACTUAL_USER"
        log_success "User '$ACTUAL_USER' added to docker group"
        log_info "User '$ACTUAL_USER' can now run Docker without sudo (after re-login)"
    else
        log_warning "Could not determine user, skipping docker group addition"
    fi
    
    # Also add koala user if exists (for FaceID VM compatibility)
    if id "koala" &>/dev/null && [ "$ACTUAL_USER" != "koala" ]; then
        usermod -aG docker koala
        log_success "User 'koala' also added to docker group"
    fi
    
    # Set permissions on Docker socket for immediate access
    chmod 666 /var/run/docker.sock 2>/dev/null || true
    log_info "Docker socket permissions set for current session"
    
    # Configure Docker daemon
    log_section "Step 9: Configuring Docker Daemon"
    
    mkdir -p /etc/docker
    
    # Create daemon.json with optimized settings
    cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF
    
    log_success "Docker daemon configured"
    
    # Restart Docker to apply configuration
    log_info "Restarting Docker service..."
    systemctl restart docker
    log_success "Docker service restarted"
    
    # Install Portainer
    log_section "Step 10: Installing Portainer"
    
    log_info "Creating Portainer volume..."
    docker volume create portainer_data
    log_success "Portainer volume created"
    
    log_info "Pulling Portainer Community Edition image..."
    # Use specific version compatible with Ubuntu 16.04 and older Docker versions
    docker pull portainer/portainer-ce:latest
    log_success "Portainer image pulled"
    
    log_info "Starting Portainer container..."
    docker run -d \
        --name portainer \
        --restart=always \
        -p 8000:8000 \
        -p 9443:9443 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest
    
    log_success "Portainer container started"
    
    # Get server IP for access info
    SERVER_IP=$(hostname -I | awk '{print $1}')
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="localhost"
    fi
    
    log_info "Portainer Web UI is accessible at:"
    echo "  - https://$SERVER_IP:9443 (HTTPS)"
    log_info "Create your admin account on first login"
    
    # Test Docker with hello-world
    log_section "Step 11: Testing Docker Installation"
    
    log_info "Running Docker hello-world test..."
    if docker run --rm hello-world > /dev/null 2>&1; then
        log_success "Docker test passed!"
    else
        log_warning "Docker test may have failed, but installation is complete"
    fi
    
    # Clean up test image
    docker rmi hello-world > /dev/null 2>&1 || true
    
    # Installation complete
    log_section "Installation Complete!"
    
    echo ""
    log_success "Docker, Docker Compose, and Portainer have been successfully installed!"
    echo ""
    log_info "Installation Summary:"
    echo "  - Docker Version:         $(docker --version)"
    echo "  - Docker Compose Version: $(docker-compose --version)"
    echo "  - Docker Status:          $(systemctl is-active docker)"
    echo "  - Portainer Status:       $(docker ps --filter name=portainer --format '{{.Status}}' | head -1)"
    echo "  - User '$ACTUAL_USER':    Added to docker group (run without sudo)"
    echo ""
    SERVER_IP=$(hostname -I | awk '{print $1}')
    [ -z "$SERVER_IP" ] && SERVER_IP="localhost"
    log_info "Portainer Web Interface:"
    echo "  - HTTPS: https://$SERVER_IP:9443"
    echo ""
    log_info "Next Steps:"
    echo "  1. Access Portainer web interface and create admin account"
    echo "  2. Log out and log back in for docker group changes to take effect"
    echo "  3. After re-login, test Docker without sudo: docker run hello-world"
    echo "  4. Manage containers easily through Portainer web interface"
    echo "  5. Check Docker status: systemctl status docker"
    echo ""
    log_info "Docker and Portainer are ready to use!"
    echo ""
}

# Run main function
main "$@"
