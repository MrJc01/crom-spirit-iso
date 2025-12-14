#!/bin/bash
# Spirit Build & Test Script

set -e

echo ""
echo "╔══════════════════════════════════════╗"
echo "║    🔮 Crom-OS Spirit Build Script    ║"
echo "╚══════════════════════════════════════╝"
echo ""

ACTION=${1:-build}

case $ACTION in
    build)
        echo "[1/3] Building Docker image..."
        docker build --target iso-builder -t spirit-iso-builder . --no-cache
        
        echo "[2/3] Extracting ISO..."
        mkdir -p output
        docker run --rm spirit-iso-builder cat /spirit-v1.0.iso > output/spirit-v1.0.iso
        
        echo "[3/3] Done!"
        ls -lh output/spirit-v1.0.iso
        
        echo ""
        echo "✅ Build complete!"
        echo "ISO: output/spirit-v1.0.iso"
        echo ""
        echo "To test locally (after download):"
        echo "  qemu-system-x86_64 -cdrom spirit-v1.0.iso -m 1024"
        ;;
    
    test)
        if [ ! -f output/spirit-v1.0.iso ]; then
            echo "❌ ISO not found. Run './build.sh build' first."
            exit 1
        fi
        
        echo "[*] Starting QEMU (text mode for Codespaces)..."
        echo "Press Ctrl+A then X to exit"
        echo ""
        
        # Install QEMU if needed
        if ! command -v qemu-system-x86_64 &> /dev/null; then
            echo "[*] Installing QEMU..."
            sudo apt-get update -qq && sudo apt-get install -y -qq qemu-system-x86
        fi
        
        # Text mode for Codespaces (no GTK)
        qemu-system-x86_64 \
            -cdrom output/spirit-v1.0.iso \
            -m 512 \
            -nographic \
            -serial mon:stdio \
            -boot d
        ;;
    
    clean)
        echo "[*] Cleaning..."
        rm -rf output/
        docker rmi spirit-iso-builder 2>/dev/null || true
        echo "✅ Clean complete"
        ;;
    
    *)
        echo "Usage: ./build.sh [command]"
        echo ""
        echo "Commands:"
        echo "  build  - Build the ISO"
        echo "  test   - Test in QEMU (text mode)"
        echo "  clean  - Remove artifacts"
        echo ""
        echo "For graphical test (after download):"
        echo "  qemu-system-x86_64 -cdrom spirit-v1.0.iso -m 1024"
        ;;
esac
