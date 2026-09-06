# FShare VM - Fully Automated Installation Guide (Cloud-Init)

## Overview

The FShare VM is a fully automated Ubuntu 22.04 LTS virtual machine configured with **cloud-init** for rapid deployment. Uses local cloud image for faster installation.

**Key Features:**
- **Cloud-Init Deployment** - 100% automated, zero manual intervention
- **Local Cloud Image** - Uses `/mnt/data/vm-images/ubuntu-22.04-cloud.img`
- **Dual Network Interfaces** for flexible connectivity
- **Java OpenJDK 21** pre-installed for Java applications
- **8 CPU cores** and **8GB RAM** for performance
- **100GB storage** for applications and data
- **Ready in 2-3 minutes** - Faster than traditional preseed installation

## Network Configuration

### Primary Interface (enp1s0)
- **IP Address**: 10.168.1.104/24
- **Gateway**: 10.168.1.1
- **Purpose**: Main internet connectivity and default route

### Secondary Interface (enp2s0)
- **IP Address**: 192.168.3.104/24
- **Gateway**: None
- **Purpose**: Internal/private network communication

## System Specifications

| Component | Specification |
|-----------|---------------|
| Deployment Method | Cloud-Init (Ubuntu Cloud Image) |
| CPU | 8 cores |
| RAM | 8GB |
| Disk | 100GB |
| OS | Ubuntu 22.04 LTS Server (Cloud Image) |
| Java | OpenJDK 21 (Latest LTS) + Maven + Gradle |
| Username | ght |
| Password | 1 |
| Installation Time | ~2-3 minutes (cloud-init) |

## Quick Start

### Create the VM

```bash
cd /home/ght/deploy
./fshare-vm
```

The script will:
1. ✓ Verify local cloud image exists
2. ✓ Create VM with dual network interfaces
3. ✓ Configure cloud-init (user, network, packages)
4. ✓ Install Ubuntu 22.04 automatically
5. ✓ Install Java OpenJDK 21, Maven, Gradle
6. ✓ Configure static IP addresses
7. ✓ Set up SSH access with keys
8. ✓ Optimize SSH and network settings
9. ✓ Automatic reboot when complete

**Installation time**: ~2-3 minutes (much faster with cloud-init!)

### Cloud-Init Advantages

- **Faster**: Uses pre-built cloud image instead of full OS install
- **Reliable**: Standardized Ubuntu cloud image
- **Flexible**: Easy to customize via cloud-init config
- **Local**: No internet required for base image

### Access the VM

**Primary Network:**
```bash
ssh ght@10.168.1.104
```

**Secondary Network:**
```bash
ssh ght@192.168.3.104
```

**Password**: `1` (SSH key also configured for passwordless access)

## Post-Installation Setup

### 1. Run Environment Setup Script

Install Docker, network tools, and Portainer:

```bash
ssh ght@10.168.1.104
cd deploy/env/ubuntu-22.04
./install-env-22.04.sh
```

This installs:
- Docker & Docker Compose
- Network monitoring tools
- Portainer (container management UI)

### 2. Verify Java Installation

Java OpenJDK 21, Maven, and Gradle are pre-installed via cloud-init:

```bash
ssh ght@10.168.1.104 'java -version'
```

Expected output:
```
openjdk version "21.0.x" 2024-xx-xx
OpenJDK Runtime Environment (build 21.0.x+x-Ubuntu-x)
OpenJDK 64-Bit Server VM (build 21.0.x+x-Ubuntu-x, mixed mode, sharing)
```

Check Maven and Gradle:
```bash
ssh ght@10.168.1.104 'mvn --version'
ssh ght@10.168.1.104 'gradle --version'
```

### 3. Verify Network Configuration

```bash
ssh ght@10.168.1.104 'ip addr show'
ssh ght@10.168.1.104 'ip route'
```

## Management Commands

### Using the Helper Script

```bash
# Show VM status
./scripts/helpers/manage-fshare.sh status

# Start/Stop VM
./scripts/helpers/manage-fshare.sh start
./scripts/helpers/manage-fshare.sh stop
./scripts/helpers/manage-fshare.sh restart

# SSH access
./scripts/helpers/manage-fshare.sh ssh      # Primary IP
./scripts/helpers/manage-fshare.sh ssh2     # Secondary IP

# Check Java
./scripts/helpers/manage-fshare.sh java

# Test network
./scripts/helpers/manage-fshare.sh ping

# Show info
./scripts/helpers/manage-fshare.sh info
```

### Using virsh Commands

```bash
# List all VMs
virsh list --all

# Start VM
virsh start fshare

# Stop VM
virsh shutdown fshare

# Force stop
virsh destroy fshare

# Open console (Ctrl+] to exit)
virsh console fshare

# VM information
virsh dominfo fshare
```

## Files Created

```
/home/ght/deploy/
├── fshare-vm                              # Main VM creation script (cloud-init)
├── fshare-vm-completion.bash              # Bash completion
├── FSHARE-VM-GUIDE.md                     # This guide
└── scripts/helpers/
    └── manage-fshare.sh                   # VM management helper

/mnt/data/
├── fshare.qcow2                           # VM disk image
└── vm-images/
    └── ubuntu-22.04-cloud.img             # Source cloud image (shared)
```

## Cloud-Init Configuration Details

The VM is configured using three cloud-init files:

### user-data
- User account (ght) with sudo access
- SSH keys and password authentication
- Package installation (Java, tools, build essentials)
- System configuration (timezone, environment variables)
- Post-installation commands

### meta-data
- Instance ID and hostname
- VM identification

### network-config
- Dual network interface configuration
- Static IP addresses
- Gateway and DNS settings

## Network Verification

### Test Primary Network (with gateway)
```bash
ping 10.168.1.104
ssh ght@10.168.1.104 'ping -c 4 8.8.8.8'   # Test internet
```

### Test Secondary Network (no gateway)
```bash
ping 192.168.3.104
ssh ght@192.168.3.104 'ip addr show enp2s0'
```

### View Routing Table
```bash
ssh ght@10.168.1.104 'ip route'
```

Expected output:
```
default via 10.168.1.1 dev enp1s0 
10.168.1.0/24 dev enp1s0 proto kernel scope link src 10.168.1.104
192.168.3.0/24 dev enp2s0 proto kernel scope link src 192.168.3.104
```

## Java Environment Details

### Environment Variables
```bash
JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
PATH=$JAVA_HOME/bin:$PATH
```

### Java Tools Available
- `java` - Java Runtime
- `javac` - Java Compiler
- `jar` - JAR tool
- `javadoc` - Documentation generator
- `mvn` - Apache Maven
- `gradle` - Gradle Build Tool

### Running Java Applications
```bash
# Compile Java application
javac MyApp.java

# Run Java application
java MyApp

# Run JAR file
java -jar application.jar
```

## Troubleshooting

### VM doesn't start
```bash
# Check VM status
virsh list --all

# View VM logs
virsh dumpxml fshare
journalctl -xe | grep libvirt

# Check cloud image exists
ls -lh /mnt/data/vm-images/ubuntu-22.04-cloud.img
```

### Cloud-init not completing
```bash
# Check cloud-init status
ssh ght@10.168.1.104 'cloud-init status'

# View cloud-init logs
ssh ght@10.168.1.104 'sudo cat /var/log/cloud-init.log'
ssh ght@10.168.1.104 'sudo cat /var/log/cloud-init-output.log'

# Check if completion marker exists
ssh ght@10.168.1.104 'ls -la ~/.cloud-init-complete'
```

### Network not configured
```bash
# Check network configuration
ssh ght@10.168.1.104 'cat /etc/netplan/00-installer-config.yaml'

# Apply network configuration
ssh ght@10.168.1.104 'sudo netplan apply'

# Restart networking
ssh ght@10.168.1.104 'sudo systemctl restart systemd-networkd'
```

### SSH access issues
```bash
# Test with password
ssh -o PreferredAuthentications=password ght@10.168.1.104

# Check SSH service
ssh ght@10.168.1.104 'sudo systemctl status ssh'
```

### Java not found
```bash
# Verify Java installation
ssh ght@10.168.1.104 'which java'
ssh ght@10.168.1.104 'dpkg -l | grep openjdk'

# Reinstall if needed
ssh ght@10.168.1.104 'sudo apt-get install -y openjdk-21-jdk'
```

## Advanced Configuration

### Add More Network Interfaces

Edit the VM and add another interface:
```bash
virsh edit fshare
```

Add another network interface section in the XML.

### Increase Disk Size
```bash
# Power off VM first
virsh shutdown fshare

# Resize disk
sudo qemu-img resize /mnt/data/fshare.qcow2 +50G

# Start VM and resize partition
virsh start fshare
ssh ght@10.168.1.104 'sudo growpart /dev/vda 1'
ssh ght@10.168.1.104 'sudo resize2fs /dev/vda1'
```

### Change Memory/CPU
```bash
# Power off VM
virsh shutdown fshare

# Edit configuration
virsh edit fshare

# Find and modify:
# <memory unit='KiB'>8388608</memory>  (8GB)
# <vcpu placement='static'>8</vcpu>
```

## Backup and Restore

### Backup VM
```bash
# Stop VM
virsh shutdown fshare

# Backup disk image
sudo cp /mnt/data/fshare.qcow2 /backup/fshare-$(date +%Y%m%d).qcow2

# Backup VM config
virsh dumpxml fshare > /backup/fshare-config-$(date +%Y%m%d).xml
```

### Restore VM
```bash
# Restore disk
sudo cp /backup/fshare-20260105.qcow2 /mnt/data/fshare.qcow2

# Define VM from config
virsh define /backup/fshare-config-20260105.xml

# Start VM
virsh start fshare
```

## Security Considerations

### Change Default Password
```bash
ssh ght@10.168.1.104
passwd
```

### Update SSH Keys
```bash
ssh ght@10.168.1.104
nano ~/.ssh/authorized_keys
```

### Firewall Configuration
```bash
ssh ght@10.168.1.104
sudo ufw enable
sudo ufw allow ssh
sudo ufw status
```

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review VM logs: `virsh console fshare`
3. Check system logs: `ssh ght@10.168.1.104 'sudo journalctl -xe'`

## License

This VM configuration is part of the deployment toolkit.

---

**Created**: January 2026  
**VM Name**: fshare  
**Purpose**: Java application hosting with dual network support  
**Method**: Cloud-Init (Ubuntu Cloud Image)  
**Image Source**: `/mnt/data/vm-images/ubuntu-22.04-cloud.img`
