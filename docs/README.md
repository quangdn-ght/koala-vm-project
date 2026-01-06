# FaceID VM Deployment

Automated Ubuntu 16.04 VM deployment system for FaceID servers using KVM/QEMU with libvirt.

## 📁 Project Structure

```
/home/ght/deploy/
├── faceid-vm              # Main entry point script
├── config/                # Configuration files
│   └── preseed.cfg       # Ubuntu automated installation config
├── docs/                  # Documentation
│   ├── README.md         # Main documentation
│   ├── INSTALL-GUIDE.md  # Installation guide
│   ├── VM-ACCESS-GUIDE.md # VM access methods
│   ├── TROUBLESHOOTING.md # Troubleshooting guide
│   ├── SUMMARY.txt       # Project summary
│   └── tasks/            # Task tracking
├── env/                   # Environment setup scripts
│   ├── install-env.sh    # Install dependencies
│   └── webmin.sh         # Webmin setup
├── iso/                   # ISO images
│   └── ubuntu-16.04.7-server-amd64.iso
└── scripts/               # All executable scripts
    ├── quick-start.sh    # Quick start wrapper
    ├── helpers/          # Utility scripts
    │   ├── generate-preseed.sh  # Generate preseed config
    │   ├── ssh-faceid.sh       # SSH helper
    │   └── test-preseed.sh     # Test preseed config
    ├── setup/            # System setup scripts
    │   ├── setup-bridge-network.sh  # Network bridge setup
    │   └── setup-nvme-mount.sh      # NVMe storage setup
    └── vm/               # VM management scripts
        ├── create-faceid-vm.sh     # Main VM creation script
        └── deploy-vm.sh           # Alternative deployment

```

## 🚀 Quick Start

### 1. Create New VM

```bash
./faceid-vm create
```

### 2. SSH to VM

```bash
./faceid-vm ssh
```

**Default credentials:**
- Username: `ght`
- Password: `1`

## 📋 Available Commands

### VM Operations
```bash
./faceid-vm create          # Create new FaceID VM
./faceid-vm ssh             # SSH into VM
./faceid-vm start           # Start VM
./faceid-vm stop            # Stop VM gracefully
./faceid-vm restart         # Restart VM
./faceid-vm destroy         # Force stop VM
./faceid-vm status          # Show VM status
./faceid-vm ip              # Get VM IP address
./faceid-vm console         # Access serial console
./faceid-vm list            # List all VMs
```

### Setup Operations
```bash
./faceid-vm setup-bridge    # Configure bridge network
./faceid-vm setup-nvme      # Configure NVMe storage
./faceid-vm setup-env       # Install dependencies
```

### Helper Tools
```bash
./faceid-vm generate-preseed  # Generate preseed config
./faceid-vm test-preseed      # Test preseed file
./faceid-vm help              # Show help
```

## 🔧 Initial Setup

### 1. Install Dependencies

```bash
./faceid-vm setup-env
```

This installs:
- KVM/QEMU virtualization
- libvirt management tools
- Cockpit web interface
- Python HTTP server

### 2. Configure Network Bridge

```bash
./faceid-vm setup-bridge
```

Configures `br0` bridge for VM networking with your physical LAN.

### 3. Configure Storage (if using NVMe)

```bash
./faceid-vm setup-nvme
```

Mounts and configures `/mnt/data` for VM disk storage.

## 📖 Documentation

- **[README.md](docs/README.md)** - Main documentation
- **[INSTALL-GUIDE.md](docs/INSTALL-GUIDE.md)** - Detailed installation guide
- **[VM-ACCESS-GUIDE.md](docs/VM-ACCESS-GUIDE.md)** - VM access methods and troubleshooting
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Common issues and solutions

## 🛠 Configuration

### VM Defaults
- **Name:** faceid
- **OS:** Ubuntu 16.04.7 LTS
- **RAM:** 16GB
- **CPUs:** 8 cores
- **Disk:** 500GB (stored on `/mnt/data`)
- **Network:** Bridged (`br0`) to physical LAN

### Customizing VM Settings

Edit [`scripts/vm/create-faceid-vm.sh`](scripts/vm/create-faceid-vm.sh):

```bash
VM_NAME="faceid"
DISK_SIZE="500"  # GB
RAM="16384"      # MB
VCPUS="8"
BRIDGE_NAME="br0"
```

### Customizing Preseed

Generate custom preseed configuration:

```bash
./faceid-vm generate-preseed [password]
```

Edit [`config/preseed.cfg`](config/preseed.cfg) for advanced customization.

## 🔍 Finding VM IP Address

The VM uses DHCP from your physical network. Find its IP:

```bash
# Using the main script
./faceid-vm ip

# Using helper script
./scripts/helpers/ssh-faceid.sh

# Manual method
VM_MAC=$(virsh domiflist faceid | grep -oP '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
ip neigh | grep "$VM_MAC"
```

## 🌐 Web Management

Access Cockpit web interface:

```
https://<host-ip>:9090
```

Manage VMs, monitor performance, and access consoles through the web UI.

## 🐛 Troubleshooting

### VM has no IP address

```bash
# Restart VM
./faceid-vm restart

# Wait and check again
sleep 30
./faceid-vm ip
```

### Can't SSH to VM

```bash
# Check VM is running
./faceid-vm status

# Try console access
./faceid-vm console
```

### Installation failed

```bash
# Check logs
virsh console faceid

# Destroy and recreate
virsh destroy faceid
virsh undefine faceid --remove-all-storage
./faceid-vm create
```

See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more solutions.

## 📝 Notes

- **Bridged Network:** VM gets IP from your router's DHCP server
- **Installation Time:** 10-15 minutes for automated installation
- **Serial Console:** Access with `./faceid-vm console` (Ctrl+] to exit)
- **Auto-start:** VM is configured to start automatically on host boot

## 🔒 Security

**Important:** Default password is `1` - change it immediately:

```bash
./faceid-vm ssh
passwd
```

## 🤝 Support

For issues or questions:
1. Check [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
2. Review [VM-ACCESS-GUIDE.md](docs/VM-ACCESS-GUIDE.md)
3. Check installation logs: `virsh console faceid`

---

**Last Updated:** December 23, 2025
