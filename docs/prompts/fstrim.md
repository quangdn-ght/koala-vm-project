You are an expert DevOps engineer and Linux sysadmin specializing in KVM/QEMU virtualization on Ubuntu Server 24.04 LTS (headless, no GUI). Your task is to create a complete, production-grade Bash script (or set of scripts) that optimally combines two methods for reclaiming dead space in qcow2 disk files: 

1. Online TRIM using fstrim (with discard=unmap enabled) for proactive, automated maintenance.
2. Offline compaction using qemu-img convert for deep, on-demand reclamation.

The goal is to minimize dead space accumulation in VM disks while ensuring minimal downtime, high safety, and efficiency for research projects involving VM performance testing, data workloads, and storage benchmarking.

Requirements for the script(s):
- **Environment Assumptions**: Host is Ubuntu 24.04 LTS with KVM/QEMU, libvirt, and a running VM (e.g., named 'faceid-vm' with disk at '/mnt/data/faceid.qcow2'). Guest VM is also Ubuntu 24.04 LTS.
- **Idempotency and Safety**: Scripts must be idempotent (safe to run multiple times), include backups during compact, and handle errors gracefully (e.g., exit with messages if VM is running during compact).
- **Structure**: Provide two main scripts:
  1. **Guest Script (inside VM)**: Enable discard=unmap (if needed via fstab), set up systemd fstrim.timer for weekly execution, and verify TRIM support.
  2. **Host Script**: Check/enable discard=unmap in libvirt XML, perform safe qemu-img convert compaction (with shutdown/start), and include options for scheduling (e.g., cron for monthly compact).
- **Steps for Guest Script**:
  1. Verify filesystem supports TRIM (e.g., ext4/xfs) and block device discard (lsblk --discard).
  2. Add 'discard' mount option to /etc/fstab for relevant partitions if not present, then remount.
  3. Enable and start fstrim.timer (systemctl enable/start fstrim.timer).
  4. Display next timer run and log instructions (journalctl -u fstrim.service).
  5. If discard not supported, print warning and suggest host-side checks.
- **Steps for Host Script**:
  1. Verify VM status and shutdown if running (virsh shutdown <vm-name> --wait).
  2. Edit libvirt XML to add discard='unmap' to disk driver if missing (virsh edit <vm-name>).
  3. Perform qemu-img convert: Create temp file, convert with -O qcow2, rename with backup of original.
  4. Start VM (virsh start <vm-name>).
  5. Verify post-compact size (qemu-img info and du -sh).
  6. Optional: Add cronjob suggestion for automated monthly compact (e.g., during low-load hours).
- **Best Practices Integration**:
  - Use strict Bash settings: #!/usr/bin/env bash, set -euo pipefail.
  - Include comments in English for each step.
  - Handle common errors: e.g., if discard='unmap' requires virtio-scsi, suggest switching driver.
  - Output professional messages in English, with success summaries and verification commands.
  - Prioritize online method (fstrim weekly) for daily maintenance; use compact for deeper cleans (e.g., after large deletions).
- **Output Deliverables**:
  - Two separate Bash script files: 'optimize-vm-guest.sh' and 'optimize-vm-host.sh'.
  - Brief usage instructions: How to run each (e.g., sudo bash optimize-vm-guest.sh inside VM).
  - Suggestions for integration into VM provisioning (e.g., cloud-init for new VMs).

Generate the scripts and instructions in a clean, professional format, ensuring they are optimized for research environments with minimal manual intervention and maximum storage efficiency.