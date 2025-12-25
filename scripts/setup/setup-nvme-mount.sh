#!/bin/bash
# Script to permanently mount /dev/nvme0n1 to /mnt/data
# This script will format (if needed), mount, and add to /etc/fstab

set -e  # Exit on error

echo "================================"
echo "NVMe Drive Setup Script"
echo "================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Error: This script must be run as root (use sudo)"
    exit 1
fi

DEVICE="/dev/nvme0n1"
MOUNT_POINT="/mnt/data"

# Check if device exists
if [ ! -b "$DEVICE" ]; then
    echo "Error: Device $DEVICE not found!"
    echo "Available block devices:"
    lsblk
    exit 1
fi

echo ""
echo "Device found: $DEVICE"
echo "Mount point: $MOUNT_POINT"
echo ""

# Show current device info
echo "Current device information:"
lsblk "$DEVICE"
echo ""

# Check if device has a filesystem
FS_TYPE=$(blkid -o value -s TYPE "$DEVICE" 2>/dev/null || echo "")

if [ -z "$FS_TYPE" ]; then
    echo "Warning: No filesystem detected on $DEVICE"
    read -p "Do you want to format it as ext4? (yes/no): " FORMAT_CONFIRM
    
    if [ "$FORMAT_CONFIRM" = "yes" ]; then
        echo "Formatting $DEVICE as ext4..."
        mkfs.ext4 -F "$DEVICE"
        echo "Formatting complete!"
        FS_TYPE="ext4"
    else
        echo "Aborted. Please format the device manually first."
        exit 1
    fi
else
    echo "Detected filesystem: $FS_TYPE"
fi

# Create mount point if it doesn't exist
if [ ! -d "$MOUNT_POINT" ]; then
    echo "Creating mount point: $MOUNT_POINT"
    mkdir -p "$MOUNT_POINT"
fi

# Get UUID of the device
UUID=$(blkid -o value -s UUID "$DEVICE")
echo "Device UUID: $UUID"

# Check if already in fstab
if grep -q "$UUID" /etc/fstab; then
    echo ""
    echo "Warning: An entry with UUID $UUID already exists in /etc/fstab"
    echo "Current entry:"
    grep "$UUID" /etc/fstab
    read -p "Do you want to replace it? (yes/no): " REPLACE_CONFIRM
    
    if [ "$REPLACE_CONFIRM" = "yes" ]; then
        # Backup fstab
        cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)
        echo "Backed up /etc/fstab"
        
        # Remove old entry
        sed -i "/UUID=$UUID/d" /etc/fstab
        echo "Removed old entry"
    else
        echo "Keeping existing entry. Attempting to mount..."
        mount -a
        if mountpoint -q "$MOUNT_POINT"; then
            echo "Successfully mounted $MOUNT_POINT"
            df -h "$MOUNT_POINT"
        fi
        exit 0
    fi
fi

# Add entry to fstab
echo ""
echo "Adding entry to /etc/fstab..."
FSTAB_ENTRY="UUID=$UUID $MOUNT_POINT $FS_TYPE defaults,nofail 0 2"
echo "$FSTAB_ENTRY" >> /etc/fstab
echo "Added: $FSTAB_ENTRY"

# Backup fstab (if not already done)
if [ ! -f /etc/fstab.backup.$(date +%Y%m%d)* ]; then
    cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)
    echo "Backed up /etc/fstab"
fi

# Mount the device
echo ""
echo "Mounting $DEVICE to $MOUNT_POINT..."
mount "$MOUNT_POINT"

# Verify mount
if mountpoint -q "$MOUNT_POINT"; then
    echo ""
    echo "================================"
    echo "Success! Drive mounted successfully"
    echo "================================"
    echo ""
    df -h "$MOUNT_POINT"
    echo ""
    echo "The drive will automatically mount at system startup."
else
    echo ""
    echo "Error: Failed to mount $MOUNT_POINT"
    echo "Check /etc/fstab for errors"
    exit 1
fi

# Set appropriate permissions
echo ""
read -p "Do you want to set ownership to current user? (yes/no): " OWNERSHIP_CONFIRM
if [ "$OWNERSHIP_CONFIRM" = "yes" ]; then
    if [ -n "$SUDO_USER" ]; then
        chown -R "$SUDO_USER":"$SUDO_USER" "$MOUNT_POINT"
        echo "Ownership set to $SUDO_USER"
    else
        read -p "Enter username for ownership: " USERNAME
        if id "$USERNAME" &>/dev/null; then
            chown -R "$USERNAME":"$USERNAME" "$MOUNT_POINT"
            echo "Ownership set to $USERNAME"
        else
            echo "User $USERNAME not found. Keeping root ownership."
        fi
    fi
fi

echo ""
echo "================================"
echo "Setup Complete!"
echo "================================"
echo "Device: $DEVICE"
echo "Mount Point: $MOUNT_POINT"
echo "Filesystem: $FS_TYPE"
echo "UUID: $UUID"
echo ""
echo "To verify mount on reboot:"
echo "  sudo reboot"
echo "  df -h | grep $MOUNT_POINT"
echo "================================"
