#!/bin/bash
# Spirit Build & Test Script v2.0

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
        echo "Commands:"
        echo "  ./build.sh test      - Test (no network)"
        echo "  ./build.sh test-net  - Test (with network for AI)"
        ;;
    
    test)
        if [ ! -f output/spirit-v1.0.iso ]; then
            echo "❌ ISO not found. Run './build.sh build' first."
            exit 1
        fi
        
        echo "[*] Starting QEMU (text mode, no network)..."
        echo "Press Ctrl+A then X to exit"
        echo ""
        
        # Install QEMU if needed
        if ! command -v qemu-system-x86_64 &> /dev/null; then
            echo "[*] Installing QEMU..."
            sudo apt-get update -qq && sudo apt-get install -y -qq qemu-system-x86
        fi
        
        qemu-system-x86_64 \
            -cdrom output/spirit-v1.0.iso \
            -m 512 \
            -nographic \
            -serial mon:stdio \
            -boot d
        ;;
    
    test-net)
        if [ ! -f output/spirit-v1.0.iso ]; then
            echo "❌ ISO not found. Run './build.sh build' first."
            exit 1
        fi
        
        echo "[*] Starting QEMU (text mode, WITH network)..."
        echo "Press Ctrl+A then X to exit"
        echo ""
        echo "To use AI with Gemini:"
        echo "  export GEMINI_API_KEY='your-key'"
        echo "  ai"
        echo ""
        
        # Install QEMU if needed
        if ! command -v qemu-system-x86_64 &> /dev/null; then
            echo "[*] Installing QEMU..."
            sudo apt-get update -qq && sudo apt-get install -y -qq qemu-system-x86
        fi
        
        qemu-system-x86_64 \
            -cdrom output/spirit-v1.0.iso \
            -m 1024 \
            -nographic \
            -serial mon:stdio \
            -boot d \
            -netdev user,id=net0 \
            -device e1000,netdev=net0
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
        echo "  build     - Build the ISO"
        echo "  test      - Test in QEMU (no network)"
        echo "  test-net  - Test in QEMU (with network for AI)"
        echo "  clean     - Remove artifacts"
        ;;
esac
