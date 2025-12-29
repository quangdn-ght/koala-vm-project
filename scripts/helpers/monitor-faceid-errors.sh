#!/bin/bash

################################################################################
# Monitor FaceID VM Python Errors - Real-time Error Monitoring
# Monitors /var/log/supervisor/koala_online-stdout.log for Python errors
# and exports them to a separate error log file
################################################################################

VM_NAME="faceid"
SOURCE_LOG="/var/log/supervisor/koala_online-stdout.log"
ERROR_LOG="/var/log/supervisor/koala_online-errors.log"
LOCAL_ERROR_LOG="./faceid-errors-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}FaceID VM Error Monitor${NC}"
echo -e "${GREEN}================================${NC}"

# Get VM IP address
get_vm_ip() {
    VM_MAC=$(virsh domiflist "$VM_NAME" 2>/dev/null | grep -oP '([0-9a-f]{2}:){5}[0-9a-f]{2}' | head -1)
    
    if [ -z "$VM_MAC" ]; then
        echo -e "${RED}Error: VM '$VM_NAME' not found or not running${NC}"
        echo "Start it with: virsh start $VM_NAME"
        exit 1
    fi
    
    # Try virsh domifaddr with guest agent first
    VM_IP=$(virsh domifaddr "$VM_NAME" --source agent 2>/dev/null | grep -v '127.0.0.1' | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    
    # If guest agent fails, try lease source
    if [ -z "$VM_IP" ]; then
        VM_IP=$(virsh domifaddr "$VM_NAME" --source lease 2>/dev/null | grep -v '127.0.0.1' | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    fi
    
    # If still empty, try arp scan
    if [ -z "$VM_IP" ]; then
        VM_IP=$(arp -an | grep "$VM_MAC" | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    fi
    
    if [ -z "$VM_IP" ]; then
        echo -e "${RED}Error: Could not determine IP address for VM '$VM_NAME'${NC}"
        echo "VM MAC: $VM_MAC"
        exit 1
    fi
    
    echo -e "${GREEN}VM IP: $VM_IP${NC}"
}

# Main monitoring function
monitor_errors() {
    echo -e "${YELLOW}Monitoring: $SOURCE_LOG${NC}"
    echo -e "${YELLOW}Remote error log: $ERROR_LOG${NC}"
    echo -e "${YELLOW}Local error log: $LOCAL_ERROR_LOG${NC}"
    echo -e "${GREEN}Press Ctrl+C to stop monitoring${NC}"
    echo -e "${GREEN}================================${NC}\n"
    
    # SSH command to monitor and filter errors
    ssh koala@$VM_IP "
        # Create error log if it doesn't exist
        sudo touch $ERROR_LOG 2>/dev/null || echo 'Note: Cannot create $ERROR_LOG (permission issue)'
        
        # Tail the log file and filter for Python errors
        sudo tail -f $SOURCE_LOG | grep --line-buffered -iE '(error|exception|traceback|failed|critical|warning|errno|raise|syntax|attribute|type|value|index|key|name|import|runtime)' | while read line; do
            echo \"\$line\"
            echo \"\$(date '+%Y-%m-%d %H:%M:%S') \$line\" | sudo tee -a $ERROR_LOG > /dev/null 2>&1 || true
        done
    " | tee -a "$LOCAL_ERROR_LOG"
}

# Trap Ctrl+C to show summary
cleanup() {
    echo -e "\n${GREEN}================================${NC}"
    echo -e "${GREEN}Monitoring stopped${NC}"
    if [ -f "$LOCAL_ERROR_LOG" ]; then
        ERROR_COUNT=$(wc -l < "$LOCAL_ERROR_LOG" 2>/dev/null || echo "0")
        echo -e "${YELLOW}Total errors logged: $ERROR_COUNT${NC}"
        echo -e "${YELLOW}Local log saved to: $LOCAL_ERROR_LOG${NC}"
    fi
    echo -e "${GREEN}================================${NC}"
    exit 0
}

trap cleanup INT TERM

# Main execution
get_vm_ip
monitor_errors
