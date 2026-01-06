#!/usr/bin/env bash

################################################################################
# VM Guest Storage Optimization Script
# Purpose: Enable and configure online TRIM (discard) for optimal storage
# Target: Ubuntu guest VM (16.04+)
# Run: Inside the VM as root or with sudo
################################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root or with sudo"
    log_info "Usage: sudo bash $0"
    exit 1
fi

clear
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║      VM Guest Storage Optimization Script                    ║"
echo "║      Enable TRIM/Discard for Efficient Storage               ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

log_info "This script will:"
echo "  1. Verify TRIM/discard support on block devices"
echo "  2. Enable discard mount option in /etc/fstab"
echo "  3. Configure systemd fstrim.timer for weekly execution"
echo "  4. Test TRIM functionality"
echo ""

# Step 1: Verify TRIM/discard support
log_info "Step 1/5: Checking TRIM/discard support..."
echo ""

# Check if lsblk supports --discard (older versions may not)
if lsblk --help 2>&1 | grep -q -- --discard; then
    log_info "Block device discard capabilities:"
    lsblk --discard
    echo ""
    
    # Check for non-zero DISC-MAX (indicates discard support)
    if lsblk --discard -n -o DISC-MAX | grep -q -v '^0B$\|^0$'; then
        log_success "TRIM/discard is supported by block devices"
        DISCARD_SUPPORTED=true
    else
        log_warning "Block devices show 0B DISC-MAX (may need host-side enablement)"
        DISCARD_SUPPORTED=false
    fi
else
    log_warning "lsblk --discard not available (older util-linux version)"
    log_info "Checking alternate method..."
    
    # Check if /sys/block/*/queue/discard_granularity exists and is non-zero
    DISCARD_SUPPORTED=false
    for dev in /sys/block/vd*/queue/discard_granularity; do
        if [ -f "$dev" ]; then
            granularity=$(cat "$dev")
            if [ "$granularity" != "0" ]; then
                log_success "Discard supported on $(basename $(dirname $(dirname $dev)))"
                DISCARD_SUPPORTED=true
            fi
        fi
    done
    
    if [ "$DISCARD_SUPPORTED" = false ]; then
        log_warning "No discard support detected in /sys/block"
    fi
fi

# Check filesystem type
log_info "Checking filesystem types..."
ROOT_FS_TYPE=$(df -T / | tail -1 | awk '{print $2}')
log_info "Root filesystem: $ROOT_FS_TYPE"

if [[ "$ROOT_FS_TYPE" =~ ^(ext4|xfs|btrfs)$ ]]; then
    log_success "Filesystem $ROOT_FS_TYPE supports TRIM"
else
    log_warning "Filesystem $ROOT_FS_TYPE may have limited TRIM support"
fi
echo ""

# Step 2: Enable discard mount option in /etc/fstab
log_info "Step 2/5: Configuring discard mount option in /etc/fstab..."
echo ""

# Backup fstab
FSTAB_BACKUP="/etc/fstab.backup-$(date +%Y%m%d-%H%M%S)"
cp /etc/fstab "$FSTAB_BACKUP"
log_info "Created backup: $FSTAB_BACKUP"

# Find root partition
ROOT_DEVICE=$(df / | tail -1 | awk '{print $1}')
log_info "Root device: $ROOT_DEVICE"

# Check if discard is already in fstab
if grep "^$ROOT_DEVICE" /etc/fstab | grep -q "discard"; then
    log_success "Discard option already present in /etc/fstab for $ROOT_DEVICE"
    FSTAB_MODIFIED=false
else
    log_info "Adding discard option to /etc/fstab for $ROOT_DEVICE..."
    
    # Add discard to existing mount options
    sed -i.tmp "/^$(echo $ROOT_DEVICE | sed 's/\//\\\//g')/s/defaults/defaults,discard/" /etc/fstab
    
    # Verify the change
    if grep "^$ROOT_DEVICE" /etc/fstab | grep -q "discard"; then
        log_success "Successfully added discard option to /etc/fstab"
        FSTAB_MODIFIED=true
    else
        log_error "Failed to add discard option to /etc/fstab"
        log_info "Please manually add 'discard' to mount options in /etc/fstab"
        FSTAB_MODIFIED=false
    fi
fi

# Display current fstab entry
log_info "Current /etc/fstab entry for root:"
grep "^$ROOT_DEVICE" /etc/fstab || log_warning "Could not find root entry in fstab"
echo ""

# Remount with new options if modified
if [ "$FSTAB_MODIFIED" = true ]; then
    log_info "Remounting root filesystem with new options..."
    if mount -o remount /; then
        log_success "Root filesystem remounted successfully"
    else
        log_warning "Remount failed. Changes will take effect after reboot."
        log_info "Reboot required to apply fstab changes"
    fi
else
    log_info "No remount needed (discard already active or not modified)"
fi
echo ""

# Step 3: Install fstrim if not present (Ubuntu usually has it)
log_info "Step 3/5: Checking fstrim availability..."
if command -v fstrim &> /dev/null; then
    log_success "fstrim command available"
    FSTRIM_VERSION=$(fstrim --version 2>&1 | head -1)
    log_info "Version: $FSTRIM_VERSION"
else
    log_warning "fstrim not found, installing util-linux..."
    apt-get update -qq
    apt-get install -y util-linux
    log_success "util-linux installed"
fi
echo ""

# Step 4: Enable and configure systemd fstrim.timer
log_info "Step 4/5: Configuring systemd fstrim.timer..."
echo ""

# Check if fstrim.timer exists
if systemctl list-unit-files | grep -q fstrim.timer; then
    log_success "fstrim.timer unit found"
    
    # Enable the timer
    log_info "Enabling fstrim.timer for automatic weekly execution..."
    systemctl enable fstrim.timer
    
    # Start the timer
    log_info "Starting fstrim.timer..."
    systemctl start fstrim.timer
    
    # Check status
    if systemctl is-active --quiet fstrim.timer; then
        log_success "fstrim.timer is active and running"
    else
        log_error "fstrim.timer failed to start"
        systemctl status fstrim.timer
    fi
    
    # Display timer schedule
    echo ""
    log_info "Timer schedule information:"
    systemctl list-timers fstrim.timer --no-pager | grep -A 1 NEXT || systemctl status fstrim.timer | grep -A 3 "Trigger:"
    
else
    log_warning "fstrim.timer not found on this system"
    log_info "Creating manual cron job as fallback..."
    
    # Create a weekly cron job
    CRON_FILE="/etc/cron.weekly/fstrim"
    cat > "$CRON_FILE" << 'CRON_EOF'
#!/bin/bash
# Automated fstrim for storage optimization
/sbin/fstrim -av >> /var/log/fstrim.log 2>&1
CRON_EOF
    
    chmod +x "$CRON_FILE"
    log_success "Created weekly cron job: $CRON_FILE"
fi
echo ""

# Step 5: Test TRIM functionality
log_info "Step 5/5: Testing TRIM functionality..."
echo ""

if [ "$DISCARD_SUPPORTED" = false ]; then
    log_warning "Skipping TRIM test because discard support is not detected"
    log_warning "This may indicate that host-side discard='unmap' is not enabled"
    echo ""
    log_info "To enable on host, run the host-side optimization script:"
    log_info "  sudo bash /home/ght/deploy/scripts/optimization/optimize-vm-host.sh"
    TRIM_TEST_SUCCESS=false
else
    log_info "Running fstrim test on root filesystem..."
    
    # Run fstrim manually
    if fstrim -v / 2>&1 | tee /tmp/fstrim-test.log; then
        TRIMMED=$(grep -oP '\d+(\.\d+)?\s*(B|K|M|G)' /tmp/fstrim-test.log | head -1 || echo "0")
        log_success "TRIM test successful"
        log_info "Trimmed: $TRIMMED"
        TRIM_TEST_SUCCESS=true
    else
        log_error "TRIM test failed"
        log_warning "Error details:"
        cat /tmp/fstrim-test.log
        log_info "This may indicate:"
        echo "  1. Host-side discard='unmap' not enabled in VM disk configuration"
        echo "  2. Disk driver doesn't support discard (use virtio-scsi instead of virtio-blk)"
        TRIM_TEST_SUCCESS=false
    fi
    rm -f /tmp/fstrim-test.log
fi
echo ""

# Summary
log_success "╔════════════════════════════════════════════════════════════╗"
log_success "║          Guest Optimization Configuration Complete         ║"
log_success "╚════════════════════════════════════════════════════════════╝"
echo ""

log_info "Configuration Summary:"
echo "  ✓ Filesystem: $ROOT_FS_TYPE"
echo "  ✓ Root device: $ROOT_DEVICE"

if [ "$FSTAB_MODIFIED" = true ]; then
    echo "  ✓ Discard mount option: Added to /etc/fstab"
else
    echo "  ✓ Discard mount option: Already present"
fi

if systemctl is-active --quiet fstrim.timer 2>/dev/null; then
    echo "  ✓ Automated TRIM: Enabled (weekly via systemd timer)"
elif [ -f /etc/cron.weekly/fstrim ]; then
    echo "  ✓ Automated TRIM: Enabled (weekly via cron)"
else
    echo "  ⚠ Automated TRIM: Not configured"
fi

if [ "$TRIM_TEST_SUCCESS" = true ]; then
    echo "  ✓ TRIM test: Successful"
else
    echo "  ⚠ TRIM test: Failed or skipped (check host-side configuration)"
fi

echo ""
log_info "Next Steps:"

if [ "$TRIM_TEST_SUCCESS" = false ]; then
    echo "  1. Run host-side optimization script:"
    echo "     sudo bash /home/ght/deploy/scripts/optimization/optimize-vm-host.sh"
    echo ""
fi

echo "  2. Monitor fstrim execution:"
echo "     journalctl -u fstrim.service"
echo ""

echo "  3. Manually trigger fstrim (testing):"
echo "     sudo fstrim -av"
echo ""

echo "  4. Check next scheduled run:"
echo "     systemctl list-timers fstrim.timer"
echo ""

if [ "$FSTAB_MODIFIED" = true ]; then
    log_warning "Reboot recommended to ensure all changes take effect"
    echo "  sudo reboot"
    echo ""
fi

log_info "Logs and backup:"
echo "  • Fstab backup: $FSTAB_BACKUP"
echo "  • Fstrim logs: journalctl -u fstrim.service"
echo "  • Manual log: /var/log/fstrim.log (if using cron)"
echo ""

log_success "Guest optimization script completed! 🚀"
