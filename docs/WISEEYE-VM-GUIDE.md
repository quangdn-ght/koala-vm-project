# WiseEye VM Manager

A centralized command-line tool for managing WiseEye virtual machines, including backup, restore, and VM lifecycle operations.

## Installation

The `wiseeye-vm` script is located in the root of the deploy directory. Make sure it's executable:

```bash
chmod +x wiseeye-vm
```

### Enable Bash Completion (Optional)

To enable tab completion for commands:

```bash
source wiseeye-vm-completion.bash
# Or add to your ~/.bashrc:
echo "source $(pwd)/wiseeye-vm-completion.bash" >> ~/.bashrc
```

## Quick Start

### Basic VM Operations

```bash
# Check VM status
./wiseeye-vm status

# Get VM IP address
./wiseeye-vm ip

# SSH into the VM
./wiseeye-vm ssh

# Start/Stop/Restart VM
./wiseeye-vm start
./wiseeye-vm stop
./wiseeye-vm restart
```

### Backup Operations

```bash
# Create a manual backup
./wiseeye-vm backup

# List all available backups
./wiseeye-vm list-backups

# Show restore instructions for a specific backup
./wiseeye-vm restore 20251228-202950
```

## Available Commands

### VM Management
- `create` - Create new WiseEye VM with Ubuntu 22.04
- `ssh` - SSH into the WiseEye VM
- `start` - Start the VM
- `stop` - Stop the VM gracefully
- `restart` - Restart the VM
- `destroy` - Force stop the VM
- `status` - Show VM status and info
- `ip` - Get VM IP address
- `console` - Access VM serial console (Ctrl+] to exit)
- `list` - List all VMs

### Backup & Recovery
- `backup` - Create manual backup
- `list-backups` - List all available backups
- `restore <timestamp>` - Show restore instructions for a backup

### Setup Commands
- `setup-network` - Complete network setup (static IP + bridge)
- `setup-bridge` - Configure bridge network
- `setup-static-ip` - Configure static IP for interface
- `setup-nvme` - Configure NVMe storage mount
- `setup-env` - Install environment dependencies

### Helper Commands
- `generate-preseed` - Generate preseed configuration
- `test-preseed` - Test preseed file
- `help` - Show help message

## Backup System

### Automatic Backups

The backup system:
- Creates snapshots of the VM disk and configuration
- Keeps the last 3 backups to save storage space
- Supports live backup of running VMs
- Stores backups in `/mnt/data/snapshot/`

### Backup Structure

Each backup consists of:
- `wiseeye-backup-YYYYMMDD-HHMMSS.qcow2` - VM disk image
- `wiseeye-backup-YYYYMMDD-HHMMSS.xml` - VM configuration

### Restore Options

The tool provides three restore methods:

1. **Quick Restore** - Replace current VM with backup
2. **New VM from Backup** - Create separate VM from backup
3. **Test Restore** - Clone for testing without affecting current VM

Use `./wiseeye-vm restore <timestamp>` to see detailed instructions for each method.

## Examples

### Create a Backup Before Maintenance

```bash
# Create backup
./wiseeye-vm backup

# Verify backup was created
./wiseeye-vm list-backups
```

### Restore from Backup

```bash
# List available backups
./wiseeye-vm list-backups

# Show restore instructions
./wiseeye-vm restore 20251228-202950

# Follow the displayed instructions
```

### Access VM Console

```bash
# Access serial console (useful when SSH is not working)
./wiseeye-vm console
# Press Ctrl+] to exit
```

## Backup Logs

Backup operations are logged to:
```
/mnt/data/snapshot/backup-wiseeye.log
```

## Troubleshooting

### Cannot SSH to VM
```bash
# Check if VM is running
./wiseeye-vm status

# Get IP address
./wiseeye-vm ip

# If IP detection fails, use console
./wiseeye-vm console
```

### Backup Failed
```bash
# Check backup logs
tail -50 /mnt/data/snapshot/backup-wiseeye.log

# Ensure enough disk space
df -h /mnt/data/
```

### VM Won't Start
```bash
# Check VM status
./wiseeye-vm status

# Try force restart
./wiseeye-vm destroy
./wiseeye-vm start

# Access console to see boot messages
./wiseeye-vm console
```

## Related Files

- [wiseeye-vm](wiseeye-vm) - Main VM manager script
- [scripts/helpers/backup-wiseeye-vm.sh](scripts/helpers/backup-wiseeye-vm.sh) - Backup script
- [wiseeye-vm-completion.bash](wiseeye-vm-completion.bash) - Bash completion
- [docs/WISEEYE-DEPLOYMENT.md](docs/WISEEYE-DEPLOYMENT.md) - Deployment guide

## See Also

- [FaceID VM Manager](faceid-vm) - Similar tool for FaceID VMs
- [docs/VM-ACCESS-GUIDE.md](docs/VM-ACCESS-GUIDE.md) - VM access methods
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues
