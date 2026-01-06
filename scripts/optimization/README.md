# VM Storage Optimization Scripts

Production-grade scripts for optimizing storage space in KVM/QEMU virtual machines using TRIM/discard and qcow2 compaction.

## Overview

These scripts implement a two-tier storage optimization strategy:

1. **Online TRIM (Guest)**: Weekly automated `fstrim` execution via systemd timer for proactive space reclamation
2. **Offline Compaction (Host)**: On-demand qcow2 disk compaction for deep space recovery

## Scripts

### 1. optimize-vm-guest.sh (Run inside VM)

**Purpose:** Configure guest VM for optimal storage with TRIM/discard support

**Features:**
- ✅ Verifies TRIM/discard support on block devices
- ✅ Enables `discard` mount option in `/etc/fstab`
- ✅ Configures systemd `fstrim.timer` for weekly execution
- ✅ Tests TRIM functionality
- ✅ Idempotent (safe to run multiple times)
- ✅ Compatible with Ubuntu 16.04+ / 18.04+ / 20.04+ / 22.04+

**Usage:**

```bash
# Copy script to VM
scp scripts/optimization/optimize-vm-guest.sh koala@10.168.1.55:/home/koala/

# SSH into VM
ssh koala@10.168.1.55

# Run script as root
sudo bash optimize-vm-guest.sh
```

**What it does:**
1. Checks filesystem type (ext4, xfs, btrfs) and TRIM support
2. Adds `discard` mount option to `/etc/fstab` for root partition
3. Enables `fstrim.timer` for weekly automatic TRIM
4. Runs test TRIM to verify functionality
5. Provides configuration summary and next steps

**Output:**
- Backup of `/etc/fstab` created before modification
- Systemd timer enabled and scheduled
- Verification of TRIM functionality
- Detailed status report

### 2. optimize-vm-host.sh (Run on host)

**Purpose:** Enable host-side discard support and perform qcow2 disk compaction

**Features:**
- ✅ Enables `discard='unmap'` in libvirt VM configuration
- ✅ Performs safe offline qcow2 compaction with backups
- ✅ Graceful VM shutdown/restart handling
- ✅ Multiple operation modes (auto, discard-only, compact-only, full)
- ✅ Space verification before compaction
- ✅ Progress monitoring during compaction

**Usage:**

```bash
# Default: Auto mode (enable discard + optional compact)
bash scripts/optimization/optimize-vm-host.sh faceid

# Enable discard only
bash scripts/optimization/optimize-vm-host.sh faceid discard-only

# Compact only (assumes discard already enabled)
bash scripts/optimization/optimize-vm-host.sh faceid compact-only

# Full optimization (enable discard + compact)
bash scripts/optimization/optimize-vm-host.sh faceid full
```

**What it does:**
1. **Discard Configuration:**
   - Verifies VM configuration
   - Adds `discard='unmap'` to libvirt XML disk driver
   - Handles VM shutdown/restart if needed

2. **Disk Compaction:**
   - Verifies available disk space
   - Creates safety backups
   - Shuts down VM gracefully
   - Converts qcow2 file to remove dead space
   - Replaces old disk with compacted version
   - Restarts VM and verifies accessibility

**Safety Features:**
- Creates two backups before compaction
- Checks for sufficient disk space
- Graceful shutdown with timeout
- Automatic rollback on failure
- Post-compaction verification

## Quick Start Guide

### Initial Setup (One-time)

**Step 1: Configure Host**
```bash
cd /home/ght/deploy
bash scripts/optimization/optimize-vm-host.sh faceid
```

This will:
- Enable discard='unmap' in VM configuration
- Optionally compact the disk
- VM restart required

**Step 2: Configure Guest**
```bash
# Copy script to VM
scp scripts/optimization/optimize-vm-guest.sh koala@10.168.1.55:/home/koala/

# SSH and run
ssh koala@10.168.1.55
sudo bash optimize-vm-guest.sh
```

This will:
- Enable discard mount option
- Set up weekly fstrim timer
- Test TRIM functionality

**Step 3: Verify Setup**

On guest VM:
```bash
# Check fstrim timer status
systemctl status fstrim.timer

# Check next scheduled run
systemctl list-timers fstrim.timer

# Manually test TRIM
sudo fstrim -av
```

On host:
```bash
# Verify discard enabled
virsh dumpxml faceid | grep discard

# Check disk info
sudo qemu-img info /mnt/data/faceid.qcow2
```

## Maintenance Schedule

### Automated (No Manual Intervention)

**Weekly TRIM (Guest):**
- Systemd timer runs `fstrim` automatically every Monday
- Logs available: `journalctl -u fstrim.service`
- Releases deleted space back to host in real-time

### On-Demand (Manual Execution)

**Monthly Compaction (Host):**
- Run during low-load hours (e.g., 2 AM on 1st of month)
- Recommended after large data deletions
- Typical duration: 5-15 minutes (depends on disk size)

```bash
# Manual monthly compaction
bash scripts/optimization/optimize-vm-host.sh faceid compact-only
```

**Optional: Automated Monthly Compaction**

Add to crontab:
```bash
# Edit crontab
crontab -e

# Add line (runs at 2 AM on 1st of every month)
0 2 1 * * bash /home/ght/deploy/scripts/optimization/optimize-vm-host.sh faceid compact-only >> /var/log/vm-compact.log 2>&1
```

## Troubleshooting

### TRIM Test Fails on Guest

**Symptom:** `fstrim: the discard operation is not supported`

**Solutions:**

1. **Verify host-side discard enabled:**
   ```bash
   virsh dumpxml faceid | grep discard
   ```
   Should show: `discard='unmap'`

2. **Check disk bus type:**
   ```bash
   virsh dumpxml faceid | grep -A 5 "device='disk'"
   ```
   - `bus='virtio'` (virtio-blk): Works but may have limitations
   - `bus='scsi'` (virtio-scsi): Optimal for discard

3. **Re-run host script:**
   ```bash
   bash scripts/optimization/optimize-vm-host.sh faceid discard-only
   ```

### Compaction Shows Minimal Space Savings

**This is normal if:**
- TRIM is working correctly (weekly fstrim already reclaiming space)
- No large deletions occurred recently
- Disk is already optimized

**Expected behavior:**
- First compaction: 20-50% space savings (if TRIM was never used)
- Subsequent compactions: 0-10% savings (TRIM handles ongoing maintenance)

### VM Won't Start After Compaction

**Recovery steps:**

1. **Check backup files:**
   ```bash
   ls -lh /mnt/data/faceid.qcow2*
   ```

2. **Restore from backup:**
   ```bash
   sudo cp /mnt/data/faceid.qcow2.old /mnt/data/faceid.qcow2
   # OR
   sudo cp /mnt/data/faceid-precompact-*.qcow2 /mnt/data/faceid.qcow2
   ```

3. **Fix permissions:**
   ```bash
   sudo chown libvirt-qemu:kvm /mnt/data/faceid.qcow2
   ```

4. **Start VM:**
   ```bash
   virsh start faceid
   ```

## Performance Impact

### Guest TRIM (Weekly)
- **CPU Impact:** Low (runs during idle timer)
- **I/O Impact:** Medium (sequential read of filesystem)
- **Duration:** 30 seconds - 2 minutes
- **Service Disruption:** None (online operation)

### Host Compaction (Monthly)
- **CPU Impact:** Medium (qemu-img conversion)
- **I/O Impact:** High (full disk read + write)
- **Duration:** 5-15 minutes (depends on disk size)
- **Service Disruption:** VM downtime during compaction

**Recommendation:** Schedule compaction during maintenance windows or low-traffic hours.

## Best Practices

### 1. Progressive Optimization Strategy

**Phase 1: Enable TRIM (Week 1)**
- Run guest script to enable weekly fstrim
- Monitor for one week
- Verify TRIM is working: `sudo fstrim -v /`

**Phase 2: Baseline Compaction (Week 2)**
- Run host compaction to establish baseline
- Document space savings
- Clean up backup files after verification

**Phase 3: Monitor (Ongoing)**
- Weekly TRIM handles routine maintenance
- Monthly compaction only if significant deletions occur
- Monitor disk growth: `watch -n 60 'du -h /mnt/data/faceid.qcow2'`

### 2. Integration with Cloud-Init

For new VM deployments, integrate guest script into cloud-init:

```yaml
#cloud-config
runcmd:
  - wget -O /tmp/optimize-vm-guest.sh https://example.com/optimize-vm-guest.sh
  - bash /tmp/optimize-vm-guest.sh
```

### 3. Monitoring and Alerting

**Track disk growth:**
```bash
# Create monitoring script
cat > /usr/local/bin/vm-disk-monitor.sh << 'EOF'
#!/bin/bash
THRESHOLD_GB=200
CURRENT_GB=$(du -b /mnt/data/faceid.qcow2 | awk '{print int($1/1024/1024/1024)}')

if [ $CURRENT_GB -gt $THRESHOLD_GB ]; then
  echo "WARNING: faceid disk size is ${CURRENT_GB} GB (threshold: ${THRESHOLD_GB} GB)"
  # Send alert (email, Slack, etc.)
fi
EOF

chmod +x /usr/local/bin/vm-disk-monitor.sh

# Add to crontab (daily check)
0 8 * * * /usr/local/bin/vm-disk-monitor.sh
```

## Technical Details

### How TRIM/Discard Works

1. **Guest filesystem** marks deleted blocks as free
2. **fstrim command** sends DISCARD commands to block device
3. **Virtio/SCSI driver** passes DISCARD to host via `discard='unmap'`
4. **QEMU** receives unmap request and marks qcow2 clusters as unused
5. **qcow2 file** releases space back to host filesystem (sparse file)

### Why Both Methods Are Needed

**TRIM (Online):**
- ✅ Real-time space release
- ✅ No downtime
- ✅ Works continuously
- ⚠️ Doesn't defragment qcow2 metadata
- ⚠️ May not reclaim all dead space

**Compaction (Offline):**
- ✅ Removes qcow2 fragmentation
- ✅ Optimizes metadata structures
- ✅ Guaranteed maximum space reclamation
- ⚠️ Requires VM downtime
- ⚠️ Time-consuming process

**Combined Strategy:**
- TRIM handles 90% of daily maintenance (automated, online)
- Compaction handles 10% deep optimization (manual, offline)
- Result: Optimal storage efficiency with minimal manual intervention

## Expected Results

### FaceID VM Example

**Before Optimization:**
```
qcow2 file: 209 GB (actual usage)
VM filesystem: 80 GB (data)
Dead space: 129 GB (deleted but not reclaimed)
```

**After Initial Compaction:**
```
qcow2 file: 177 GB (actual usage)
VM filesystem: 80 GB (data)
Dead space: 97 GB (qcow2 overhead - normal)
Savings: 32 GB reclaimed
```

**After Weekly TRIM (Ongoing):**
```
Space released: Real-time as files are deleted
Prevents dead space buildup
Monthly compaction typically shows 0-5 GB additional savings
```

### Typical Space Savings

| Scenario | TRIM Only | TRIM + Compact |
|----------|-----------|----------------|
| New VM (fresh install) | 0% | 0% |
| Active VM (6 months old) | 15-25% | 20-30% |
| Active VM (1+ year old) | 20-35% | 30-50% |
| VM with large deletions | 30-50% | 40-60% |

## Files Created/Modified

### Guest VM
- `/etc/fstab` - Modified to add discard mount option
- `/etc/fstab.backup-*` - Backup before modification
- Systemd timer: `fstrim.timer` (enabled)
- Systemd service: `fstrim.service` (triggered by timer)

### Host
- Libvirt XML: Modified to add `discard='unmap'`
- Backup files during compaction:
  - `/mnt/data/faceid.qcow2.old`
  - `/mnt/data/faceid-precompact-*.qcow2`

## Support

For issues or questions:
1. Check logs: `journalctl -u fstrim.service`
2. Verify configuration: `virsh dumpxml faceid | grep discard`
3. Review this README for troubleshooting steps
4. Check detailed report: `/home/ght/deploy/report/faceid-vm-analysis-and-compaction-*.md`

## References

- [QEMU Documentation - Discard](https://www.qemu.org/docs/master/system/images.html)
- [libvirt Domain XML - Disk Discard](https://libvirt.org/formatdomain.html#hard-drives-floppy-disks-cdroms)
- [systemd fstrim.timer](https://www.freedesktop.org/software/systemd/man/fstrim.timer.html)
- [Ubuntu Manual - fstrim](http://manpages.ubuntu.com/manpages/jammy/man8/fstrim.8.html)

---

**Last Updated:** January 6, 2026  
**Version:** 1.0.0  
**Tested On:** Ubuntu Server 24.04 LTS (host), Ubuntu 16.04-22.04 (guests)
