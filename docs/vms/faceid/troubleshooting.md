# VM Permission Fix & Troubleshooting Guide

## Issue Resolved: Permission Denied Error

### Problem
```
ERROR internal error: process exited while connecting to monitor: 
Could not open '/home/ght/deploy/ubuntu-16.04.7-server-amd64.iso': Permission denied
```

### Root Cause
The `/home/ght/` directory had restrictive permissions (750) that prevented the `libvirt-qemu` user from accessing files inside subdirectories.

### Solution Applied
```bash
sudo chmod 755 /home/ght/
sudo chmod 755 /home/ght/deploy/
```

### Why This Works
- KVM/QEMU runs as the `libvirt-qemu` user (UID 64055, GID 994)
- This user needs execute (x) permission on all parent directories to access files
- The permission 755 means: owner=rwx, group=rx, others=rx
- This allows libvirt-qemu to traverse the directory path to reach the ISO file

---

## Alternative Solutions

### Option 1: Move ISO to Standard Location (Recommended)
```bash
sudo mkdir -p /var/lib/libvirt/images
sudo mv /home/ght/deploy/ubuntu-16.04.7-server-amd64.iso /var/lib/libvirt/images/
sudo chown libvirt-qemu:kvm /var/lib/libvirt/images/ubuntu-16.04.7-server-amd64.iso
```

Then update the script to use: `/var/lib/libvirt/images/ubuntu-16.04.7-server-amd64.iso`

### Option 2: Add libvirt-qemu to User Group
```bash
sudo usermod -a -G ght libvirt-qemu
sudo systemctl restart libvirtd
```

---

## Creating the FaceID VM

### Quick Start
```bash
./create-faceid-vm.sh
```

### Manual Creation
```bash
virt-install \
    --name faceid \
    --ram 2048 \
    --vcpus 2 \
    --disk path=/var/lib/libvirt/images/faceid.qcow2,size=20,format=qcow2 \
    --cdrom /home/ght/deploy/ubuntu-16.04.7-server-amd64.iso \
    --os-variant ubuntu16.04 \
    --network network=default \
    --graphics vnc,listen=0.0.0.0 \
    --noautoconsole
```

---

## VM Management Commands

### Check VM Status
```bash
virsh list --all
virsh dominfo faceid
```

### Start/Stop VM
```bash
virsh start faceid
virsh shutdown faceid
virsh destroy faceid  # Force stop
```

### Access VM Console
```bash
# Text console
virsh console faceid

# Get VNC port
virsh vncdisplay faceid

# Via Cockpit Web UI
https://YOUR-IP:9090
```

### Delete VM
```bash
virsh destroy faceid
virsh undefine faceid --remove-all-storage
```

---

## Troubleshooting Checklist

### 1. Verify Permissions
```bash
# Check directory permissions
ls -ld /home/ght/ /home/ght/deploy/

# Check ISO permissions
ls -la /home/ght/deploy/ubuntu-16.04.7-server-amd64.iso

# Test access as libvirt-qemu user
sudo -u libvirt-qemu ls /home/ght/deploy/
```

### 2. Verify Services
```bash
sudo systemctl status libvirtd
sudo systemctl status virtlogd
```

### 3. Check AppArmor (if enabled)
```bash
sudo aa-status | grep libvirt
sudo aa-complain /usr/sbin/libvirtd  # Temporary fix
```

### 4. Check Disk Space
```bash
df -h /var/lib/libvirt/images
```

### 5. Verify Network
```bash
virsh net-list --all
virsh net-start default  # If not active
```

### 6. Check Logs
```bash
sudo journalctl -xeu libvirtd
sudo tail -f /var/log/libvirt/qemu/faceid.log
```

---

## Security Best Practices

### For Production
1. **Use dedicated storage location**: `/var/lib/libvirt/images/`
2. **Set proper SELinux contexts** (if using SELinux):
   ```bash
   sudo semanage fcontext -a -t virt_image_t "/path/to/iso(/.*)?"
   sudo restorecon -R /path/to/iso
   ```
3. **Use specific group permissions** instead of world-readable
4. **Regular backups** of VM disk images

### Current Setup (Development)
- Home directory made readable (755) - acceptable for dev environment
- ISO accessible to libvirt-qemu user
- Standard libvirt storage pool can be used for VM disks

---

## Expected Installation Process

After running the creation script:

1. VM will be created and started
2. Ubuntu 16.04 installer will boot from ISO
3. Access via Cockpit web UI to complete installation:
   - Navigate to: https://YOUR-IP:9090
   - Click "Virtual Machines"
   - Click on "faceid" VM
   - Use the console to complete Ubuntu installation

4. Follow Ubuntu installation prompts:
   - Select language
   - Configure network
   - Create user account
   - Install system
   - Reboot

5. After installation:
   - Remove the CD-ROM from VM:
     ```bash
     virsh change-media faceid hda --eject
     ```
   - Or via Cockpit web interface

---

## Verification

After fixing permissions, verify with:
```bash
# Test that libvirt-qemu can access the ISO
sudo -u libvirt-qemu cat /home/ght/deploy/ubuntu-16.04.7-server-amd64.iso > /dev/null && echo "✓ Access OK" || echo "✗ Access DENIED"
```
