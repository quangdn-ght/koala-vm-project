# Automated VM Installation Guide

## Overview
This setup provides **fully automated** Ubuntu 16.04 VM installation with zero user interaction.

## Features
✅ **No manual prompts** - Complete unattended installation
✅ **Full disk usage** - Automatically uses entire virtual disk
✅ **Pre-configured user** - Ready to login immediately
✅ **Serial console** - Accessible via virsh console
✅ **SSH ready** - OpenSSH server pre-installed
✅ **Network configured** - DHCP automatically configured

---

## Quick Start

### 0. Prerequisites (First Time Setup)
Before creating VMs, ensure the storage and network are configured:

```bash
# 1. Mount NVMe drive to /mnt/data (for VM storage)
sudo ./setup-nvme-mount.sh

# 2. Setup bridge network for physical LAN access
sudo ./setup-bridge-network.sh
```

### 1. Run the Automated Installation
```bash
./create-faceid-vm.sh
```

The script will:
- Start a temporary web server for preseed configuration
- Create VM with 500GB disk (on /mnt/data), 16GB RAM, 8 CPUs
- Bridge networking to physical LAN (gets IP from your DHCP)
- Install Ubuntu 16.04 completely automatically
- Takes approximately 10-15 minutes

### 2. Default Credentials
- **Username:** `ght`
- **Password:** `1`

### 3. Access Your VM
```bash
# Get VM IP address
virsh domifaddr faceid

# SSH into VM
ssh ght@<VM-IP>

# Or use console
virsh console faceid
```

---

## Installation Process

### What Happens During Installation
1. ✓ VM created with specified resources
2. ✓ Ubuntu installer boots automatically
3. ✓ Preseed configuration downloaded from temporary web server
4. ✓ Partitioning: Entire disk used automatically (no LVM)
5. ✓ Base system installed
6. ✓ Packages installed: openssh-server, vim, curl, wget, net-tools
7. ✓ GRUB bootloader installed
8. ✓ Serial console configured
9. ✓ VM reboots automatically
10. ✓ Ready to use!

### Disk Partitioning (Automatic)
The preseed uses the "atomic" recipe which creates:
- Primary partition for root (/) using entire disk
- Swap partition (auto-sized based on RAM)
- No LVM overhead

---

## Customization

### Change Password
```bash
# Generate new preseed with custom password
./generate-preseed.sh "YourNewPassword123"

# Then run the VM creation
./create-faceid-vm.sh
```

### Modify VM Resources
Edit [create-faceid-vm.sh](create-faceid-vm.sh):
```bash
DISK_SIZE="500"    # 500GB disk
RAM="16384"        # 16GB RAM
VCPUS="8"          # 8 CPUs
DISK_PATH="/mnt/data/${VM_NAME}.qcow2"  # Storage location
BRIDGE_NAME="br0"  # Bridge interface
```

**Note:** VM disk is stored on `/mnt/data` which should be your NVMe drive.

### Add More Packages
Edit [preseed.cfg](preseed.cfg), line 54:
```
d-i pkgsel/include string openssh-server vim curl wget net-tools build-essential git
```

### Change Partitioning Scheme
Edit [preseed.cfg](preseed.cfg), line 30-31:
```
# For LVM:
d-i partman-auto/method string lvm

# For encrypted:
d-i partman-auto/method string crypto
```

---

## VM Management

### Basic Commands
```bash
# Start VM
virsh start faceid

# Stop VM (graceful)
virsh shutdown faceid

# Force stop
virsh destroy faceid

# Restart
virsh reboot faceid

# Delete VM completely
virsh destroy faceid
virsh undefine faceid --remove-all-storage
```

### Get VM Information
```bash
# VM status and info
virsh dominfo faceid

# IP address
virsh domifaddr faceid

# Console access
virsh console faceid
# (Press Ctrl+] to exit console)

# List all VMs
virsh list --all
```

### VM Networking
```bash
# Show VM network info
virsh domiflist faceid

# Show IP address
virsh domifaddr faceid

# Port forwarding (example: forward host 2222 to VM 22)
virsh qemu-monitor-command faceid --hmp "hostfwd_add ::2222-:22"
```

---

## Troubleshooting

### Installation Not Completing
```bash
# Watch installation progress
virsh console faceid

# Check if preseed was downloaded
# Look for "Downloading preseed file" in console
```

### Can't Access Preseed URL
```bash
# Check if web server is running
netstat -tuln | grep 8000

# Test preseed URL manually
curl http://$(hostname -I | awk '{print $1}'):8000/preseed.cfg

# Check firewall
sudo ufw status
```

### VM Won't Start
```bash
# Check VM logs
sudo tail -f /var/log/libvirt/qemu/faceid.log

# Check libvirt status
sudo systemctl status libvirtd

# Verify disk space
df -h /var/lib/libvirt/images
```

### Installation Stuck
```bash
# Connect to console to see what's happening
virsh console faceid

# If needed, destroy and recreate
virsh destroy faceid
virsh undefine faceid --remove-all-storage
./create-faceid-vm.sh
```

### Serial Console Not Working
The preseed configures serial console automatically. If it's not working:
```bash
# Verify serial console in VM
virsh console faceid
# Press Enter a few times to get login prompt
```

---

## Advanced Configuration

### Preseed File Explanation

**Key Sections in preseed.cfg:**

1. **Localization (Lines 4-6):** Language, keyboard, console setup
2. **Network (Lines 9-12):** Auto DHCP configuration
3. **Partitioning (Lines 24-40):** Full disk automatic partitioning
4. **User Account (Lines 43-50):** Username and password
5. **Packages (Lines 57-61):** Software to install
6. **Boot Loader (Lines 64-66):** GRUB installation
7. **Late Commands (Lines 73-79):** Post-install configuration

### Manual Installation Options

If you need to install manually:
```bash
virt-install \
    --name faceid-manual \
    --ram 2048 \
    --vcpus 2 \
    --disk path=/var/lib/libvirt/images/faceid-manual.qcow2,size=20 \
    --cdrom /home/ght/deploy/ubuntu-16.04.7-server-amd64.iso \
    --os-variant ubuntu16.04 \
    --network network=default \
    --graphics vnc,listen=0.0.0.0
```

Then connect via VNC:
```bash
virsh vncdisplay faceid-manual
# Connect with VNC client to the displayed port
```

---

## Verification Steps

### After Installation Completes
```bash
# 1. Check VM is running
virsh list

# 2. Get IP address
virsh domifaddr faceid

# 3. Wait for VM to fully boot (30 seconds)
sleep 30

# 4. Test SSH connection
ssh ght@<VM-IP>
# Password: 1

# 5. Inside VM, verify installation
uname -a
df -h
free -h
```

---

## Security Notes

### Change Default Password Immediately
```bash
# SSH into VM
ssh ght@<VM-IP>

# Change password
passwd
```

### Disable Password Authentication (Use SSH Keys)
```bash
# On host, generate key
ssh-keygen -t ed25519

# Copy to VM
ssh-copy-id ght@<VM-IP>

# On VM, disable password auth
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

---

## Files Reference

- [create-faceid-vm.sh](create-faceid-vm.sh) - Main installation script
- [preseed.cfg](preseed.cfg) - Automated installation configuration
- [generate-preseed.sh](generate-preseed.sh) - Generate preseed with custom password
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Permission fixes and advanced troubleshooting

---

## Support

For issues related to:
- **Permissions:** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Installation failures:** Check console with `virsh console faceid`
- **Network issues:** Verify with `virsh net-list --all`
- **Libvirt problems:** Check logs in `/var/log/libvirt/`
