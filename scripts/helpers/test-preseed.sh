#!/bin/bash

################################################################################
# Test Preseed Configuration
# Validates preseed file and tests web server
################################################################################

set -e

PRESEED_FILE="/home/ght/deploy/preseed.cfg"
PORT="8000"

echo "================================"
echo "Testing Preseed Configuration"
echo "================================"
echo ""

# Check if preseed file exists
if [ ! -f "$PRESEED_FILE" ]; then
    echo "❌ Preseed file not found: $PRESEED_FILE"
    exit 1
fi
echo "✓ Preseed file exists"

# Check file size
SIZE=$(stat -f%z "$PRESEED_FILE" 2>/dev/null || stat -c%s "$PRESEED_FILE" 2>/dev/null)
echo "✓ Preseed file size: $SIZE bytes"

# Check for required preseed directives
echo ""
echo "Checking required directives..."

check_directive() {
    if grep -q "$1" "$PRESEED_FILE"; then
        echo "  ✓ $2"
    else
        echo "  ❌ Missing: $2"
    fi
}

check_directive "d-i debian-installer/locale" "Locale configuration"
check_directive "d-i netcfg/choose_interface" "Network configuration"
check_directive "d-i partman-auto/method" "Partitioning method"
check_directive "d-i passwd/username" "User account"
check_directive "d-i passwd/user-password-crypted" "User password"
check_directive "d-i grub-installer/bootdev" "Boot loader"

echo ""
echo "Testing web server..."

# Start web server
cd "$(dirname "$PRESEED_FILE")"
python3 -m http.server $PORT > /dev/null 2>&1 &
WEB_PID=$!
sleep 2

# Get host IP
HOST_IP=$(hostname -I | awk '{print $1}')
URL="http://${HOST_IP}:${PORT}/preseed.cfg"

echo "  URL: $URL"

# Test access
if curl -s -o /dev/null -w "%{http_code}" "$URL" | grep -q "200"; then
    echo "  ✓ Preseed accessible via HTTP"
else
    echo "  ❌ Failed to access preseed via HTTP"
fi

# Cleanup
kill $WEB_PID 2>/dev/null || true

echo ""
echo "================================"
echo "Configuration Test Complete!"
echo "================================"
echo ""
echo "Ready to create VM with:"
echo "  ../../scripts/vm/create-faceid-vm.sh"
