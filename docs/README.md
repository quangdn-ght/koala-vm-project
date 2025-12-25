# FaceID VM Deployment - Automated Installation

Complete automated VM deployment system for Ubuntu 16.04 with KVM/QEMU on Ubuntu Server 24.04 LTS.

## 🚀 Quick Start

```bash
# Install KVM/QEMU + Cockpit (one-time setup)
sudo ./deploy-vm.sh

# Create fully automated VM installation
./create-faceid-vm.sh
```

**Installation time:** ~10-15 minutes (completely automated)

**Default credentials:**
- Username: `faceid`
- Password: `faceid123`

---

## 📋 What's Included

### Installation Scripts
- **[deploy-vm.sh](deploy-vm.sh)** - Install KVM/QEMU and Cockpit web interface
- **[create-faceid-vm.sh](create-faceid-vm.sh)** - Create VM with fully automated Ubuntu 16.04 installation
- **[preseed.cfg](preseed.cfg)** - Unattended installation configuration

### Helper Scripts
- **[test-preseed.sh](test-preseed.sh)** - Validate preseed configuration
- **[generate-preseed.sh](generate-preseed.sh)** - Generate preseed with custom password
- **[quick-start.sh](quick-start.sh)** - Quick VM creation shortcut

### Documentation
- **[INSTALL-GUIDE.md](INSTALL-GUIDE.md)** - Complete automated installation guide
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Permission fixes and troubleshooting
- **[task.md](task.md)** - Original requirements

---

## 🎯 Features

### ✅ Fully Automated Installation
- **Zero user interaction** - No prompts or wizards
- **Complete disk usage** - Automatically partitions and uses entire virtual disk
- **Pre-configured networking** - DHCP configured automatically
- **SSH ready** - OpenSSH server installed and configured
- **Serial console enabled** - Access via `virsh console`

### ✅ Smart Configuration
- **Preseed-based** - Industry-standard Debian/Ubuntu automated installation
- **Temporary web server** - Automatically serves preseed during installation
- **Full error handling** - Detailed logging and error messages
- **Automatic cleanup** - Removes temporary resources after installation

### ✅ Production Ready
- **Optimized partitioning** - Uses atomic recipe for simple, efficient layout
- **Security configured** - Non-root user with sudo access
- **Essential packages** - vim, curl, wget, net-tools pre-installed
- **Guest tools** - QEMU guest agent for better VM integration

---

## 📖 Documentation

### For First-Time Setup
1. Read [task.md](task.md) - Understand the requirements
2. Run [deploy-vm.sh](deploy-vm.sh) - Install KVM/QEMU (one-time)
3. Follow [INSTALL-GUIDE.md](INSTALL-GUIDE.md) - Create your VM

### For Troubleshooting
- **Permission errors:** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Installation issues:** Check [INSTALL-GUIDE.md](INSTALL-GUIDE.md) troubleshooting section
- **VM management:** Both guides have comprehensive VM command references

---

## 🔧 Usage Examples

### Basic Usage
```bash
# Create VM with defaults
./create-faceid-vm.sh
```

### With Custom Password
```bash
# Generate new preseed with custom password
./generate-preseed.sh "MySecurePassword123"

# Create VM
./create-faceid-vm.sh
```

### Test Before Creating
```bash
# Validate preseed configuration
./test-preseed.sh

# Then create VM
./create-faceid-vm.sh
```

---

## 🖥️ VM Specifications

**Default Configuration:**
- **Name:** faceid
- **OS:** Ubuntu 16.04.7 Server
- **RAM:** 2GB (2048MB)
- **CPUs:** 2 virtual cores
- **Disk:** 20GB (fully utilized)
- **Network:** NAT (default network)
- **Console:** Serial console enabled

**Disk Layout (Automatic):**
- Partition 1: Swap (auto-sized based on RAM)
- Partition 2: Root (/) - Remaining space (ext4)

**Pre-installed Packages:**
- openssh-server
- vim, curl, wget, net-tools
- qemu-guest-agent
- Standard server packages

---

## 🎓 Step-by-Step Process

### What Happens When You Run create-faceid-vm.sh

1. **Validation**
   - Checks ISO file exists
   - Checks preseed file exists
   - Removes existing VM if present

2. **Web Server Setup**
   - Starts Python HTTP server on port 8000
   - Serves preseed.cfg for installer access

3. **VM Creation**
   - Creates 20GB qcow2 disk image
   - Allocates 2GB RAM and 2 CPUs
   - Configures virtio drivers for performance

4. **Automated Installation** (10-15 minutes)
   - Boots Ubuntu installer
   - Downloads preseed configuration
   - Partitions disk automatically
   - Installs base system
   - Installs selected packages
   - Configures user account
   - Installs GRUB bootloader
   - Enables serial console
   - Reboots automatically

5. **Completion**
   - Stops web server
   - Displays VM information
   - Shows access methods
   - VM ready to use!

---

## 🔌 Access Your VM

### Via SSH
```bash
# Get VM IP
virsh domifaddr faceid

# Connect
ssh faceid@<VM-IP>
```

### Via Serial Console
```bash
virsh console faceid
# Press Ctrl+] to exit
```

### Via Cockpit Web UI
```bash
# Open in browser
https://<HOST-IP>:9090

# Navigate to: Virtual Machines → faceid
```

---

## 🛠️ VM Management

### Start/Stop
```bash
virsh start faceid           # Start VM
virsh shutdown faceid        # Graceful shutdown
virsh destroy faceid         # Force stop
virsh reboot faceid          # Restart
```

### Information
```bash
virsh list --all             # List all VMs
virsh dominfo faceid         # VM details
virsh domifaddr faceid       # Get IP address
```

### Delete VM
```bash
virsh destroy faceid
virsh undefine faceid --remove-all-storage
```

---

## ⚙️ Customization

### Change VM Resources

Edit [create-faceid-vm.sh](create-faceid-vm.sh):
```bash
DISK_SIZE="40"     # Change disk to 40GB
RAM="4096"         # Change RAM to 4GB
VCPUS="4"          # Change to 4 CPUs
```

### Change Username/Password

Edit [preseed.cfg](preseed.cfg):
```bash
# Line 44: Change username
d-i passwd/username string YOUR_USERNAME

# Generate new password hash
mkpasswd -m sha-512

# Line 48: Update password hash
d-i passwd/user-password-crypted password YOUR_HASH
```

Or use the helper:
```bash
./generate-preseed.sh "YourPassword"
```

### Add More Packages

Edit [preseed.cfg](preseed.cfg) line 57:
```bash
d-i pkgsel/include string openssh-server vim curl wget net-tools python3 git
```

### Change Disk Partitioning

Edit [preseed.cfg](preseed.cfg):
```bash
# For LVM (line 30)
d-i partman-auto/method string lvm

# For different partition scheme (line 31)
# Options: atomic, home, multi
d-i partman-auto/choose_recipe select home
```

---

## 🔐 Security

### Change Password After First Login
```bash
ssh faceid@<VM-IP>
passwd
```

### Use SSH Keys
```bash
# Generate key on host
ssh-keygen -t ed25519

# Copy to VM
ssh-copy-id faceid@<VM-IP>

# Disable password auth on VM
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

---

## 📊 System Requirements

### Host Machine
- Ubuntu Server 24.04 LTS (or compatible)
- Hardware virtualization support (Intel VT-x or AMD-V)
- At least 4GB RAM (8GB+ recommended)
- 30GB+ free disk space
- Python 3 (for preseed web server)

### Network
- Host must be able to reach internet (for Ubuntu mirrors)
- VM will get IP via DHCP on default network
- Port 9090 for Cockpit (optional)

---

## 🐛 Troubleshooting Quick Reference

### VM Creation Fails
```bash
# Check permissions
ls -la /home/ght/deploy/ubuntu-16.04.7-server-amd64.iso

# Fix if needed
sudo chmod 755 /home/ght/
sudo chmod 755 /home/ght/deploy/
```

### Preseed Not Loading
```bash
# Test preseed accessibility
./test-preseed.sh

# Check firewall
sudo ufw status
```

### Installation Hangs
```bash
# Connect to console to see progress
virsh console faceid

# Check logs
sudo tail -f /var/log/libvirt/qemu/faceid.log
```

Full troubleshooting guide: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

## 📝 Files Overview

| File | Purpose |
|------|---------|
| `deploy-vm.sh` | One-time KVM/QEMU installation |
| `create-faceid-vm.sh` | **Main script** - Creates automated VM |
| `preseed.cfg` | Automated installation configuration |
| `generate-preseed.sh` | Generate preseed with custom password |
| `test-preseed.sh` | Validate preseed before installation |
| `quick-start.sh` | Quick shortcut for VM creation |
| `INSTALL-GUIDE.md` | Complete installation guide |
| `TROUBLESHOOTING.md` | Permission fixes and troubleshooting |
| `README.md` | This file |
| `task.md` | Original requirements |

---

## ✨ Advanced Usage

### Create Multiple VMs
```bash
# Edit VM name in script
sed -i 's/VM_NAME="faceid"/VM_NAME="faceid-2"/' create-faceid-vm.sh
./create-faceid-vm.sh
```

### Clone Existing VM
```bash
virt-clone \
  --original faceid \
  --name faceid-clone \
  --file /var/lib/libvirt/images/faceid-clone.qcow2
```

### Backup VM
```bash
# Backup disk image
sudo cp /var/lib/libvirt/images/faceid.qcow2 /backup/faceid-$(date +%Y%m%d).qcow2

# Backup VM definition
virsh dumpxml faceid > faceid-definition.xml
```

---

## 🤝 Contributing

Improvements welcome! Key areas:
- Additional OS support (Ubuntu 18.04, 20.04, 22.04)
- More preseed recipes (LVM, encrypted, custom partitioning)
- Cloud-init integration
- Ansible playbooks for post-installation

---

## 📚 Resources

- [Debian Preseed Documentation](https://wiki.debian.org/DebianInstaller/Preseed)
- [Ubuntu Autoinstall Guide](https://ubuntu.com/server/docs/install/autoinstall)
- [KVM Documentation](https://www.linux-kvm.org/page/Documents)
- [Libvirt Documentation](https://libvirt.org/docs.html)

---

## 📄 License

This project is provided as-is for educational and deployment purposes.

---

## ✅ Verification

After installation completes:
```bash
# Check VM is running
virsh list | grep faceid

# Get IP
VM_IP=$(virsh domifaddr faceid | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)

# Wait for boot
sleep 30

# Test SSH
ssh faceid@$VM_IP "uname -a && df -h"
```

Expected output:
- Ubuntu 16.04 kernel version
- 20GB disk with root partition using most space
- SSH connection successful

---

**🎉 You're ready! Run `./create-faceid-vm.sh` to get started.**
