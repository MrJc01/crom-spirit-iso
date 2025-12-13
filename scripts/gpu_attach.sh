#!/bin/bash
# GPU Attach Script - Restores GPU to original driver
# Usage: ./gpu_attach.sh

set -e

echo "🎮 GPU Attach Script (Restore)"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root"
    exit 1
fi

# Read restore configuration
RESTORE_FILE="/tmp/spirit_gpu_restore.conf"
if [ ! -f "$RESTORE_FILE" ]; then
    echo "❌ No restore configuration found at $RESTORE_FILE"
    echo "   Run gpu_detach.sh first"
    exit 1
fi

echo "   Reading restore configuration..."

while IFS=':' read -r addr driver; do
    if [ -z "$addr" ] || [ -z "$driver" ] || [ "$driver" == "none" ]; then
        continue
    fi

    echo "   Restoring $addr to $driver..."

    # Get current driver
    current_driver_path="/sys/bus/pci/devices/$addr/driver"
    if [ -L "$current_driver_path" ]; then
        current_driver=$(basename $(readlink "$current_driver_path"))
        
        # Unbind from vfio-pci
        if [ "$current_driver" == "vfio-pci" ]; then
            echo "      Unbinding from vfio-pci..."
            echo "$addr" > /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || true
        fi
    fi

    # Bind to original driver
    echo "      Binding to $driver..."
    
    # Load driver module if needed
    modprobe "$driver" 2>/dev/null || true
    
    # Trigger rescan for driver binding
    echo "$addr" > /sys/bus/pci/drivers/$driver/bind 2>/dev/null || {
        # If direct bind fails, try rescan
        echo 1 > /sys/bus/pci/devices/$addr/remove 2>/dev/null || true
        echo 1 > /sys/bus/pci/rescan 2>/dev/null || true
    }

done < "$RESTORE_FILE"

# Cleanup
rm -f "$RESTORE_FILE"

echo "✅ GPU restored to host"
echo "   Display should be active on the GPU now"
