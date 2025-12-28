# Environment Setup Scripts

This directory contains scripts for setting up the environment on different Ubuntu versions.

## Scripts

### install-docker-ubuntu16.sh
Docker and Docker Compose installation script for Ubuntu 16.04 (Xenial).

**Features:**
- Installs Docker CE (latest supported version for Ubuntu 16.04)
- Installs Docker Compose v1.29.2
- Configures Docker daemon with optimized settings
- Adds user to docker group
- Enables Docker service on startup

**Usage:**
```bash
# Manual installation
sudo bash /home/ght/deploy/env/install-docker-ubuntu16.sh

# Or run within the VM after SSH
sudo bash install-docker-ubuntu16.sh
```

**Auto Installation:**
This script is automatically executed during VM creation via the preseed configuration. Docker will be pre-installed on the FaceID VM.

**Post-Installation:**
After the VM is created, Docker is ready to use:
```bash
# Check Docker version
docker --version

# Check Docker Compose version
docker-compose --version

# Test Docker
docker run hello-world

# Check Docker status
systemctl status docker
```

**User Configuration:**
The `koala` user is automatically added to the `docker` group, allowing Docker commands without sudo (after re-login).

### install-env.sh
Environment setup script for Ubuntu 24.04 LTS (Noble) - includes Docker, network tools, and Portainer.

## VM Creation with Docker Pre-installed

When you create the FaceID VM using the provided scripts, Docker is automatically installed during the OS installation process:

```bash
# Create FaceID VM (Docker auto-installed)
./scripts/vm/create-faceid-vm.sh
```

The preseed configuration handles the Docker installation automatically via the `late_command` directive.

## Docker Configuration

The Docker daemon is configured with the following settings:
- **Log Driver:** json-file
- **Max Log Size:** 10MB per file
- **Max Log Files:** 3 files
- **Storage Driver:** overlay2

Configuration file location: `/etc/docker/daemon.json`

## Troubleshooting

### Docker Service Not Running
```bash
sudo systemctl start docker
sudo systemctl status docker
```

### User Not in Docker Group
```bash
sudo usermod -aG docker $USER
# Log out and log back in
```

### Docker Compose Not Found
```bash
# Verify installation
ls -l /usr/local/bin/docker-compose
# Re-create symlink if needed
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
```

### Check Docker Installation
```bash
docker info
docker-compose version
```

## Version Information

- **Ubuntu:** 16.04 LTS (Xenial Xerus)
- **Docker CE:** Latest supported for Ubuntu 16.04
- **Docker Compose:** 1.29.2 (last version supporting Ubuntu 16.04)

## Notes

- Ubuntu 16.04 reached end-of-life in April 2021 but ESM (Extended Security Maintenance) is available until 2026
- Docker Compose v1.29.2 is the last version with full Ubuntu 16.04 support
- For production environments, consider upgrading to Ubuntu 20.04 or 22.04 LTS
