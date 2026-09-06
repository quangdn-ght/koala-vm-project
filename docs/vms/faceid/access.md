# VM Access Guide

## Quick SSH Access

The easiest way to SSH to the FaceID VM:

```bash
./ssh-faceid.sh
```

This helper script automatically detects the VM's IP address (works with both NAT and bridged networks).

## Manual IP Detection

If you need to find the VM's IP address manually:

### Method 1: Using MAC address (works for bridged networks)
```bash
# Get VM's MAC address
VM_MAC=$(virsh domiflist faceid | grep -oP '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)

# Find IP from neighbor table
ip neigh | grep "$VM_MAC"
```

### Method 2: Using virsh (works for NAT networks)
```bash
virsh domifaddr faceid
```

## Direct SSH Connection

Once you have the IP address:
```bash
ssh ght@<IP_ADDRESS>
```

**Default credentials:**
- Username: `ght`
- Password: `1`

## Troubleshooting

### VM has no IP address
```bash
# Check VM status
virsh dominfo faceid

# Restart VM
virsh destroy faceid
virsh start faceid

# Wait 30 seconds and check again
sleep 30
./ssh-faceid.sh
```

### SSH connection refused
```bash
# Check if SSH service is running in the VM
virsh console faceid
# (Press Enter, then login and run: sudo systemctl status ssh)
```

### Can't find VM in neighbor table
```bash
# Ping broadcast to populate ARP table
ping -c 3 -b $(ip -4 addr show br0 | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | sed 's/\.[0-9]*$/.255/')

# Then try again
./ssh-faceid.sh
```

## VM Management Commands

```bash
# Start VM
virsh start faceid

# Stop VM gracefully
virsh shutdown faceid

# Force stop VM
virsh destroy faceid

# Check VM status
virsh dominfo faceid

# List all VMs
virsh list --all

# Access serial console
virsh console faceid
# (Press Ctrl+] to exit console)
```
