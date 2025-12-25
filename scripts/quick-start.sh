#!/bin/bash
# Quick VM Creation - FaceID with Ubuntu 16.04
# Run this after fixing permissions

echo "================================"
echo "Creating FaceID VM..."
echo "================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/vm/create-faceid-vm.sh"

echo ""
echo "================================"
echo "Quick Access:"
echo "================================"
echo "Web UI: https://$(hostname -I | awk '{print $1}'):9090"
echo ""
echo "VM Commands:"
echo "  virsh list --all      # List all VMs"
echo "  virsh start faceid    # Start VM"
echo "  virsh console faceid  # Access console"
echo "================================"
