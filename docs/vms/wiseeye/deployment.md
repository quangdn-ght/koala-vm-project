# WiseEye VM Deployment Guide

## Overview
This guide covers the complete deployment of a WiseEye VM with automated installation and configuration.

## VM Specifications
- **VM Name**: wiseeye
- **OS**: Ubuntu 22.04.5 LTS Server
- **CPU**: 8 cores
- **RAM**: 8 GB
- **Storage**: 256 GB
- **Location**: /mnt/data/wiseeye.qcow2
- **ISO**: /mnt/data/iso/ubuntu-22.04.5-live-server-amd64.iso

## Credentials
- **Username**: ght
- **Password**: "1"
- **SSH**: Passwordless (SSH key-based authentication pre-configured)

## Quick Start

### Option 1: Complete Automated Deployment (Recommended)
This single command creates the VM, installs Docker, and deploys the wiseeye-sync application:

```bash
cd /home/ght/deploy
./scripts/helpers/deploy-wiseeye-vm.sh
```

**This script will:**
1. Create the WiseEye VM with Ubuntu 22.04
2. Wait for VM to boot and be accessible
3. Install Docker and Docker Compose
4. Copy application files (docker-compose.yml and .env)
5. Start all containers with docker-compose

**Duration**: Approximately 15-20 minutes

### Option 2: Step-by-Step Manual Deployment

#### Step 1: Create the VM
```bash
cd /home/ght/deploy
./scripts/vm/create-wiseeye-vm.sh
```

This creates the VM with automated Ubuntu 22.04 installation (10-15 minutes).

#### Step 2: Connect to VM
After VM creation, note the IP address and connect:
```bash
ssh ght@<VM_IP>
```

#### Step 3: Run Post-Install Script
From your **host machine**, copy and run the post-install script:
```bash
./scripts/helpers/post-install-wiseeye.sh
```

Or copy it to the VM and run:
```bash
scp scripts/helpers/post-install-wiseeye.sh ght@<VM_IP>:/tmp/
ssh ght@<VM_IP> "bash /tmp/post-install-wiseeye.sh"
```

#### Step 4: Deploy Application
Copy application files to VM:
```bash
ssh ght@<VM_IP> "mkdir -p /home/ght/deploy/koala/wiseeye-sync"
scp koala/wiseeye-sync/docker-compose.yml ght@<VM_IP>:/home/ght/deploy/koala/wiseeye-sync/
scp koala/wiseeye-sync/.env ght@<VM_IP>:/home/ght/deploy/koala/wiseeye-sync/
```

Start containers:
```bash
ssh ght@<VM_IP>
cd /home/ght/deploy/koala/wiseeye-sync
docker-compose up -d
```

## Application Access

After deployment, the wiseeye-sync application will be accessible at:

- **Frontend**: http://<VM_IP>:3128
- **Backend API**: http://<VM_IP>:3003
- **SQL Server**: <VM_IP>:1433
  - Username: sa
  - Password: Giahung@2024

## Container Management

### View Container Status
```bash
ssh ght@<VM_IP> 'cd ~/deploy/koala/wiseeye-sync && docker-compose ps'
```

### View Logs
```bash
ssh ght@<VM_IP> 'cd ~/deploy/koala/wiseeye-sync && docker-compose logs -f'
```

### Restart Containers
```bash
ssh ght@<VM_IP> 'cd ~/deploy/koala/wiseeye-sync && docker-compose restart'
```

### Stop Containers
```bash
ssh ght@<VM_IP> 'cd ~/deploy/koala/wiseeye-sync && docker-compose down'
```

### Start Containers
```bash
ssh ght@<VM_IP> 'cd ~/deploy/koala/wiseeye-sync && docker-compose up -d'
```

### View Specific Container Logs
```bash
ssh ght@<VM_IP> 'cd ~/deploy/koala/wiseeye-sync && docker-compose logs -f wiseeye-backend'
ssh ght@<VM_IP> 'cd ~/deploy/koala/wiseeye-sync && docker-compose logs -f wiseeye-frontend'
ssh ght@<VM_IP> 'cd ~/deploy/koala/wiseeye-sync && docker-compose logs -f wiseeye-sqlserver'
```

## VM Management

### Start VM
```bash
virsh start wiseeye
```

### Stop VM (graceful shutdown)
```bash
virsh shutdown wiseeye
```

### Force Stop VM
```bash
virsh destroy wiseeye
```

### View VM Status
```bash
virsh dominfo wiseeye
```

### Access VM Console
```bash
virsh console wiseeye
# Press Ctrl+] to exit console
```

### List All VMs
```bash
virsh list --all
```

### Get VM IP Address
```bash
# Method 1: Using virsh
virsh domifaddr wiseeye

# Method 2: Using neighbor table
VM_MAC=$(virsh domiflist wiseeye | grep -oP '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
ip neigh | grep -i "$VM_MAC"
```

## Files and Directories

### Host Machine
- VM creation script: `/home/ght/deploy/scripts/vm/create-wiseeye-vm.sh`
- Post-install script: `/home/ght/deploy/scripts/helpers/post-install-wiseeye.sh`
- Complete deployment script: `/home/ght/deploy/scripts/helpers/deploy-wiseeye-vm.sh`
- Preseed config: `/home/ght/deploy/config/wiseeye-preseed.cfg`
- Application files: `/home/ght/deploy/koala/wiseeye-sync/`

### VM (wiseeye)
- Application directory: `/home/ght/deploy/koala/wiseeye-sync/`
- Docker compose file: `/home/ght/deploy/koala/wiseeye-sync/docker-compose.yml`
- Environment file: `/home/ght/deploy/koala/wiseeye-sync/.env`

## Troubleshooting

### VM Creation Issues

**ISO file not found:**
```bash
# Verify ISO exists
ls -lh /mnt/data/iso/ubuntu-22.04.5-live-server-amd64.iso
```

**VM already exists:**
The create script will prompt to destroy and recreate. To manually remove:
```bash
virsh destroy wiseeye
virsh undefine wiseeye --remove-all-storage
```

### SSH Connection Issues

**SSH not ready after installation:**
Wait a few minutes and try again:
```bash
ssh ght@<VM_IP>
```

**SSH key not working:**
Verify the key is in your ~/.ssh/ directory. The preseed includes the public key automatically.

### Docker Issues

**Docker requires sudo:**
After Docker installation, you must log out and back in, or run:
```bash
newgrp docker
```

**Containers not starting:**
Check logs:
```bash
docker-compose logs
```

Check available disk space:
```bash
df -h
```

### Application Issues

**SQL Server container unhealthy:**
Check SQL Server logs:
```bash
docker-compose logs wiseeye-sqlserver
```

Verify password and connection:
```bash
docker exec -it wiseeye-sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P Giahung@2024 -Q "SELECT @@VERSION"
```

**Backend connection issues:**
Verify environment variables in `.env` file:
```bash
cat /home/ght/deploy/koala/wiseeye-sync/.env
```

## Network Configuration

The VM uses bridged networking (br0) to obtain an IP on the physical LAN via DHCP. This allows direct network access from other machines on the network.

**Bridge interface**: br0  
**Network mode**: DHCP (automatic IP assignment)

## Backup and Recovery

### Backup VM Disk
```bash
virsh shutdown wiseeye
cp /mnt/data/wiseeye.qcow2 /mnt/data/backups/wiseeye.qcow2.backup
virsh start wiseeye
```

### Clone VM
```bash
virt-clone --original wiseeye --name wiseeye-clone --file /mnt/data/wiseeye-clone.qcow2
```

### Export VM Configuration
```bash
virsh dumpxml wiseeye > /mnt/data/backups/wiseeye-config.xml
```

## Performance Tuning

### View VM Resource Usage
```bash
virsh domstats wiseeye
```

### Modify VM Resources (while VM is stopped)
```bash
# Change RAM (to 16GB)
virsh setmaxmem wiseeye 16G --config
virsh setmem wiseeye 16G --config

# Change CPU cores (to 12)
virsh setvcpus wiseeye 12 --config --maximum
virsh setvcpus wiseeye 12 --config
```

## Security Considerations

1. **Change default password**: After first login, change the password:
   ```bash
   passwd
   ```

2. **Update system regularly**:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

3. **Configure firewall** (if needed):
   ```bash
   sudo ufw enable
   sudo ufw allow 22/tcp    # SSH
   sudo ufw allow 3128/tcp  # Frontend
   sudo ufw allow 3003/tcp  # Backend
   sudo ufw allow 1433/tcp  # SQL Server
   ```

4. **Secure SQL Server**: Change the default SA password in the `.env` file and redeploy.

## Support

For issues or questions:
- Check logs: `docker-compose logs -f`
- Verify VM status: `virsh dominfo wiseeye`
- Check network: `ping <VM_IP>`
- Review this guide: `/home/ght/deploy/docs/WISEEYE-DEPLOYMENT.md`

---

**Last Updated**: December 28, 2025  
**VM Specs**: 8 cores, 8GB RAM, 256GB storage  
**OS**: Ubuntu 22.04.5 LTS Server
