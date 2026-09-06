Summary
Why the wiseeye VM didn't use the qcow2 file in data:

When you restored from the backup XML configuration, it contained a reference to the old disk path (ubuntu-22.04-cloud.img), not wiseeye.qcow2.

Why switching to wiseeye.qcow2 causes boot failure:

The wiseeye.qcow2 file has a broken network configuration where:

Static netplan config exists but wasn't being applied properly
Cloud-init was conflicting with the static network config
After disabling cloud-init, netplan still doesn't configure the network correctly
Current Working Solution:

The VM is now working using ubuntu-22.04-cloud.img which:

Uses cloud-init for network configuration
Gets the static IP 10.168.1.56 (likely from DHCP reservation or cloud-init metadata)
Has all Docker containers running properly
Recommendation:

Keep using ubuntu-22.04-cloud.img as the disk since it's working. If you want to use wiseeye.qcow2, you'll need to properly fix the netplan configuration and ensure it's applied during boot.