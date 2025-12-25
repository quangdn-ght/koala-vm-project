#!/bin/bash

################################################################################
# Generate Preseed with Custom Password
# Usage: ./generate-preseed.sh [password]
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_FILE="$PROJECT_ROOT/config/preseed.cfg"

PASSWORD="${1:-faceid123}"
USERNAME="faceid"
HOSTNAME="faceid"

# Generate password hash
PASS_HASH=$(echo "$PASSWORD" | mkpasswd -m sha-512 -s)

cat > "$OUTPUT_FILE" << 'PRESEED_START'
#### Preseed Configuration for Automated Ubuntu 16.04 Installation
#### Full disk automatic installation without user prompts

### Localization
d-i debian-installer/locale string en_US.UTF-8
d-i keyboard-configuration/xkb-keymap select us
d-i console-setup/ask_detect boolean false

### Network configuration
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string faceid
d-i netcfg/get_domain string local
d-i netcfg/wireless_wep string

### Mirror settings
d-i mirror/country string manual
d-i mirror/http/hostname string archive.ubuntu.com
d-i mirror/http/directory string /ubuntu
d-i mirror/http/proxy string

### Clock and time zone setup
d-i clock-setup/utc boolean true
d-i time/zone string UTC
d-i clock-setup/ntp boolean true

### Partitioning - Use entire disk automatically
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-auto/disk string /dev/vda
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-auto/purge_lvm_from_device boolean true
d-i partman-auto-lvm/guided_size string max
d-i partman-auto-lvm/new_vg_name string vg00
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i partman-partitioning/confirm_write_new_label boolean true

### Account setup
d-i passwd/root-login boolean false
d-i passwd/user-fullname string FaceID Admin
d-i passwd/username string USERNAME_PLACEHOLDER
PRESEED_START

# Add password line with the generated hash
echo "d-i passwd/user-password-crypted password ${PASS_HASH}" >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" << 'PRESEED_END'
d-i user-setup/allow-password-weak boolean true
d-i user-setup/encrypt-home boolean false

### Base system installation
d-i base-installer/install-recommends boolean true
d-i base-installer/kernel/image string linux-generic

### Package selection
tasksel tasksel/first multiselect standard, server
d-i pkgsel/include string openssh-server vim curl wget net-tools
d-i pkgsel/upgrade select full-upgrade
d-i pkgsel/update-policy select none
d-i pkgsel/updatedb boolean true

### Boot loader installation
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean true
d-i grub-installer/bootdev string /dev/vda

### Finishing up the installation
d-i finish-install/reboot_in_progress note
d-i debian-installer/exit/poweroff boolean false

### Custom commands
d-i preseed/late_command string \
    in-target sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/GRUB_CMDLINE_LINUX_DEFAULT="console=tty0 console=ttyS0,115200n8"/' /etc/default/grub ; \
    in-target update-grub ; \
    in-target systemctl enable serial-getty@ttyS0.service ; \
    in-target apt-get update ; \
    in-target apt-get install -y qemu-guest-agent || true
PRESEED_END

# Replace username placeholder
sed -i "s/USERNAME_PLACEHOLDER/$USERNAME/g" "$OUTPUT_FILE"

echo "Preseed file generated: $OUTPUT_FILE"
echo "Username: $USERNAME"
echo "Password: $PASSWORD"
