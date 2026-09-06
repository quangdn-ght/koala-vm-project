You are a professional automation expert on Ubuntu Server 24.04 LTS (headless, no GUI). Perform the following steps sequentially to install and configure KVM/QEMU along with Cockpit for managing virtual machines through a web interface.

Execute one step at a time, check the result after each step, and only proceed if the previous step succeeded. If any error occurs, display the error and suggest a fix before continuing.

1. Update the system:
   sudo apt update && sudo apt upgrade -y

2. Install the necessary packages for KVM/QEMU and Cockpit:
   sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst cpu-checker cockpit cockpit-machines

3. Check KVM hardware virtualization support:
   kvm-ok
   If the output shows "KVM acceleration can be used", continue. Otherwise, report the error and stop.

4. Enable and start the libvirt service:
   sudo systemctl enable --now libvirtd
   sudo systemctl status libvirtd --no-pager

5. Enable and start the Cockpit service:
   sudo systemctl enable --now cockpit.socket
   sudo systemctl status cockpit.socket --no-pager

6. Add the current user (assume it's the user you're logged in as, e.g., ubuntu) to the required groups so VMs can be managed without sudo:
   sudo adduser $USER libvirt
   sudo adduser $USER kvm
   (Note: After this command, you need to log out and log back in for the group changes to take effect, or use `newgrp libvirt` and `newgrp kvm` in the current session.)

7. Verify that Cockpit is listening on port 9090:
   sudo ss -tuln | grep 9090

8. Display final access instructions:
   - Access Cockpit via browser: https://<server-IP>:9090
   - Log in with your system user account (e.g., ubuntu)
   - The "Virtual Machines" addon is already installed and will appear in the left menu.

9. Finally, print a completion message:
   echo "KVM/QEMU + Cockpit installation completed!"
   echo "Access URL: https://$(hostname -I | awk '{print $1}'):9090"
   echo "Note: The first time you access it, your browser will warn about a self-signed certificate – accept the risk and continue."

Execute the steps sequentially and report the result after each major step (1–9). Do not skip any step.

Create VM with 500GB disk, 16GB RAM, 8 CPUs. ip dhcp with physical LAN, ex: 192.168.0.1/24.
important: vm of entire disk locate on host of /mnt/data path