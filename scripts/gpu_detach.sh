#!/bin/bash
# GPU Detach Script - Unbinds GPU from host and binds to vfio-pci
# Usage: ./gpu_detach.sh [PCI_ADDRESS]
# Example: ./gpu_detach.sh 0000:01:00.0

set -e

GPU_ADDR="${1:-0000:01:00.0}"
GPU_AUDIO="${GPU_ADDR%.*}.1"  # Audio device usually at .1

echo "🎮 GPU Detach Script"
echo "   Target GPU: $GPU_ADDR"
echo "   Audio Device: $GPU_AUDIO"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root"
    exit 1
fi

# Validate GPU address format
if ! [[ "$GPU_ADDR" =~ ^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9]$ ]]; then
    echo "❌ Invalid PCI address format: $GPU_ADDR"
    echo "   Expected format: 0000:01:00.0"
    exit 1
fi

# Check if GPU device exists
if [ ! -d "/sys/bus/pci/devices/$GPU_ADDR" ]; then
    echo "❌ GPU device not found: $GPU_ADDR"
    echo "   Available devices:"
    lspci -nn | grep -i "vga\|3d\|display" || echo "   No GPU devices found"
    exit 1
fi

# Function to get current driver
get_driver() {
    local addr=$1
    local driver_path="/sys/bus/pci/devices/$addr/driver"
    if [ -L "$driver_path" ]; then
        basename $(readlink "$driver_path")
    else
        echo "none"
    fi
}

# Store current drivers for restore
CURRENT_GPU_DRIVER=$(get_driver $GPU_ADDR)
CURRENT_AUDIO_DRIVER=$(get_driver $GPU_AUDIO)

echo "   Current GPU driver: $CURRENT_GPU_DRIVER"
echo "   Current Audio driver: $CURRENT_AUDIO_DRIVER"

# Verify driver is not already vfio-pci
if [ "$CURRENT_GPU_DRIVER" == "vfio-pci" ]; then
    echo "✅ GPU is already bound to vfio-pci"
    exit 0
fi

# Save driver info for restore
mkdir -p /var/lib/spirit
echo "$GPU_ADDR:$CURRENT_GPU_DRIVER" > /var/lib/spirit/gpu_restore.conf
echo "$GPU_AUDIO:$CURRENT_AUDIO_DRIVER" >> /var/lib/spirit/gpu_restore.conf

# Load vfio modules
modprobe vfio
modprobe vfio_iommu_type1
modprobe vfio-pci

# Unbind GPU from current driver
if [ "$CURRENT_GPU_DRIVER" != "none" ]; then
    echo "   Unbinding GPU from $CURRENT_GPU_DRIVER..."
    echo "$GPU_ADDR" > /sys/bus/pci/drivers/$CURRENT_GPU_DRIVER/unbind 2>/dev/null || {
        echo "⚠️  Warning: Could not unbind GPU (may already be unbound)"
    }
fi

# Unbind Audio from current driver
if [ -d "/sys/bus/pci/devices/$GPU_AUDIO" ] && [ "$CURRENT_AUDIO_DRIVER" != "none" ]; then
    echo "   Unbinding Audio from $CURRENT_AUDIO_DRIVER..."
    echo "$GPU_AUDIO" > /sys/bus/pci/drivers/$CURRENT_AUDIO_DRIVER/unbind 2>/dev/null || true
fi

# Get vendor:device IDs
GPU_VENDOR=$(cat /sys/bus/pci/devices/$GPU_ADDR/vendor)
GPU_DEVICE=$(cat /sys/bus/pci/devices/$GPU_ADDR/device)

echo "   GPU ID: ${GPU_VENDOR}:${GPU_DEVICE}"

# Bind to vfio-pci using driver_override (more reliable method)
echo "   Binding GPU to vfio-pci..."
echo "vfio-pci" > /sys/bus/pci/devices/$GPU_ADDR/driver_override
echo "$GPU_ADDR" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || {
    # Fallback: use new_id method
    echo "${GPU_VENDOR#0x} ${GPU_DEVICE#0x}" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true
}

# Handle audio device if present
if [ -d "/sys/bus/pci/devices/$GPU_AUDIO" ]; then
    AUDIO_VENDOR=$(cat /sys/bus/pci/devices/$GPU_AUDIO/vendor 2>/dev/null || echo "")
    AUDIO_DEVICE=$(cat /sys/bus/pci/devices/$GPU_AUDIO/device 2>/dev/null || echo "")
    
    if [ -n "$AUDIO_VENDOR" ]; then
        echo "   Binding Audio to vfio-pci..."
        echo "vfio-pci" > /sys/bus/pci/devices/$GPU_AUDIO/driver_override 2>/dev/null || true
        echo "$GPU_AUDIO" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
    fi
fi

# Verify binding
FINAL_DRIVER=$(get_driver $GPU_ADDR)
if [ "$FINAL_DRIVER" == "vfio-pci" ]; then
    echo "✅ GPU successfully detached and bound to vfio-pci"
    echo "   GPU is now ready for VM passthrough"
else
    echo "❌ Failed to bind GPU to vfio-pci (current driver: $FINAL_DRIVER)"
    exit 1
fi
