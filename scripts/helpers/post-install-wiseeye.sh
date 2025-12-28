#!/bin/bash

################################################################################
# Post-Install Automation for WiseEye VM
# This script runs inside the WiseEye VM after initial installation
# It installs Docker, Docker Compose, and prepares the environment
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

print_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Check if running on correct VM
HOSTNAME=$(hostname)
if [ "$HOSTNAME" != "wiseeye" ]; then
    log_warning "This script is designed for the WiseEye VM (hostname: wiseeye)"
    log_info "Current hostname: $HOSTNAME"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

print_section "WiseEye VM Post-Install Automation"

# Update system
print_section "Updating System Packages"
log_info "Updating package lists..."
sudo apt-get update -qq

log_info "Upgrading packages (this may take a few minutes)..."
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

log_success "System packages updated"

# Install essential tools
print_section "Installing Essential Tools"
log_info "Installing additional utilities..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    software-properties-common \
    ca-certificates \
    gnupg \
    lsb-release \
    htop \
    iotop \
    nmap \
    dnsutils \
    traceroute

log_success "Essential tools installed"

# Check if Docker is already installed
if command -v docker &> /dev/null; then
    log_warning "Docker is already installed"
    docker --version
else
    # Install Docker using the official install script
    print_section "Installing Docker"
    log_info "Downloading and running Docker installation script..."
    
    # Download install script
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    
    # Run install script
    sudo sh /tmp/get-docker.sh
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Enable Docker service
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Clean up
    rm -f /tmp/get-docker.sh
    
    log_success "Docker installed successfully"
    docker --version
fi

# Install Docker Compose plugin
print_section "Verifying Docker Compose"
if docker compose version &> /dev/null; then
    log_success "Docker Compose plugin is available"
    docker compose version
else
    log_warning "Docker Compose plugin not found, installing..."
    
    # Install Docker Compose plugin
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+' || echo "v2.23.0")
    sudo mkdir -p /usr/local/lib/docker/cli-plugins
    sudo curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose
    sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    
    log_success "Docker Compose plugin installed"
    docker compose version
fi

# Install standalone docker-compose CLI for compatibility
print_section "Installing docker-compose CLI"
if command -v docker-compose &> /dev/null; then
    log_success "docker-compose CLI is already installed"
    docker-compose --version
else
    log_info "Installing standalone docker-compose CLI..."
    
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+' || echo "v2.23.0")
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    log_success "docker-compose CLI installed"
    docker-compose --version
fi

# Configure Docker daemon
print_section "Configuring Docker"
log_info "Setting up Docker daemon configuration..."

sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

sudo systemctl restart docker
log_success "Docker configured"

# Create deployment directory
print_section "Creating Deployment Directory"
log_info "Setting up /home/ght/deploy directory..."
mkdir -p /home/ght/deploy
cd /home/ght/deploy

log_success "Deployment directory ready"

# Verify installations
print_section "Verifying Installations"
log_info "Docker version:"
docker --version

log_info "Docker Compose plugin:"
docker compose version

log_info "docker-compose CLI:"
docker-compose --version

log_info "Docker service status:"
sudo systemctl status docker --no-pager -l | head -n 5

# Test Docker (needs newgrp or re-login to work without sudo)
log_info "Testing Docker..."
if docker ps > /dev/null 2>&1; then
    log_success "Docker is working correctly"
else
    log_warning "Docker requires re-login to work without sudo"
    log_info "Run: newgrp docker (or log out and back in)"
fi

# Display summary
print_section "Installation Complete!"
echo ""
log_success "WiseEye VM environment is ready!"
echo ""
log_info "Installed components:"
echo "  ✓ Docker Engine"
echo "  ✓ Docker Compose Plugin"
echo "  ✓ docker-compose CLI"
echo "  ✓ Essential system tools"
echo ""
log_info "Next steps:"
echo "  1. Log out and back in (or run: newgrp docker)"
echo "  2. Clone your application code"
echo "  3. Deploy with docker-compose"
echo ""
log_warning "IMPORTANT: To use Docker without sudo, you must:"
echo "  - Log out and log back in, OR"
echo "  - Run: newgrp docker"
echo ""

log_success "Post-install automation completed!"
