#!/bin/bash

################################################################################
# SSH to FaceID VM - Helper Script
# Automatically detects VM IP and connects via SSH
################################################################################

VM_NAME="faceid"

# Get VM MAC address
VM_MAC=$(virsh domiflist "$VM_NAME" 2>/dev/null | grep -oP '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)

if [ -z "$VM_MAC" ]; then
    echo "Error: VM '$VM_NAME' not found or not running"
    echo "Start it with: virsh start $VM_NAME"
    exit 1
fi

# Try virsh domifaddr with guest agent first
VM_IP=$(virsh domifaddr "$VM_NAME" --source agent 2>/dev/null | grep -v '127.0.0.1' | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)

# Try default virsh domifaddr
if [ -z "$VM_IP" ]; then
    VM_IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | grep -v '127.0.0.1' | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
fi

# If that fails, try neighbor table (for bridged networks)
if [ -z "$VM_IP" ]; then
    VM_IP=$(ip neigh | grep -i "$VM_MAC" | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
fi

# If still not found, try ARP table (requires net-tools)
if [ -z "$VM_IP" ] && command -v arp >/dev/null 2>&1; then
    VM_IP=$(arp -an | grep -i "$VM_MAC" | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
fi

# Last resort: scan the network with nmap (requires nmap and sudo)
if [ -z "$VM_IP" ] && command -v nmap >/dev/null 2>&1; then
    # Get bridge network subnet
    BRIDGE_SUBNET=$(ip addr show br0 2>/dev/null | grep -oP 'inet \K([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+' | head -1)
    if [ -n "$BRIDGE_SUBNET" ]; then
        echo "Scanning network to find VM..."
        VM_IP=$(sudo nmap -sn "$BRIDGE_SUBNET" 2>/dev/null | grep -B 2 -i "$VM_MAC" | grep "Nmap scan report" | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    fi
fi

if [ -z "$VM_IP" ]; then
    echo "Error: Could not find IP address for VM '$VM_NAME'"
    echo "VM MAC address: $VM_MAC"
    echo ""
    echo "Try checking manually:"
    echo "  ip neigh | grep '$VM_MAC'"
    echo "  virsh domifaddr $VM_NAME"
    echo "  arp -an | grep '$VM_MAC'"
    echo "  sudo nmap -sn <network-subnet>"
    exit 1
fi

echo "Connecting to $VM_NAME at $VM_IP..."
ssh koala@$VM_IP
