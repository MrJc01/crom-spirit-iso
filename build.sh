#!/bin/bash
# Spirit Build & Test Script
# Run this in Codespaces or any Linux environment with Docker

set -e

CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

echo ""
echo -e "${CYAN}╔══════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║    🔮 Crom-OS Spirit Build Script    ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════╝${RESET}"
echo ""

# Parse arguments
ACTION=${1:-build}

case $ACTION in
    build)
        echo -e "${YELLOW}[1/3] Building Docker image...${RESET}"
        docker build --target iso-builder -t spirit-iso-builder . --no-cache
        
        echo -e "${YELLOW}[2/3] Extracting ISO...${RESET}"
        mkdir -p output
        sudo docker run --rm spirit-iso-builder cat /spirit-v1.0.iso > output/spirit-v1.0.iso
        
        echo -e "${YELLOW}[3/3] Verifying...${RESET}"
        ls -lh output/spirit-v1.0.iso
        
        echo ""
        echo -e "${GREEN}✅ Build complete!${RESET}"
        echo -e "ISO location: ${CYAN}output/spirit-v1.0.iso${RESET}"
        echo ""
        echo "To test: ./build.sh test"
        ;;
    
    test)
        if [ ! -f output/spirit-v1.0.iso ]; then
            echo -e "${RED}❌ ISO not found. Run './build.sh build' first.${RESET}"
            exit 1
        fi
        
        echo -e "${YELLOW}[*] Starting QEMU...${RESET}"
        echo -e "${CYAN}Press Ctrl+Alt+G to release mouse${RESET}"
        echo ""
        
        # Check if qemu is installed
        if ! command -v qemu-system-x86_64 &> /dev/null; then
            echo -e "${YELLOW}[*] Installing QEMU...${RESET}"
            sudo apt-get update && sudo apt-get install -y qemu-system-x86
        fi
        
        qemu-system-x86_64 \
            -cdrom output/spirit-v1.0.iso \
            -m 1024 \
            -enable-kvm 2>/dev/null || \
        qemu-system-x86_64 \
            -cdrom output/spirit-v1.0.iso \
            -m 1024
        ;;
    
    test-nographic)
        if [ ! -f output/spirit-v1.0.iso ]; then
            echo -e "${RED}❌ ISO not found. Run './build.sh build' first.${RESET}"
            exit 1
        fi
        
        echo -e "${YELLOW}[*] Starting QEMU (text mode)...${RESET}"
        echo -e "${CYAN}Press Ctrl+A then X to exit${RESET}"
        echo ""
        
        qemu-system-x86_64 \
            -cdrom output/spirit-v1.0.iso \
            -m 512 \
            -nographic \
            -append "console=ttyS0"
        ;;
    
    clean)
        echo -e "${YELLOW}[*] Cleaning...${RESET}"
        rm -rf output/
        docker rmi spirit-iso-builder 2>/dev/null || true
        echo -e "${GREEN}✅ Clean complete${RESET}"
        ;;
    
    *)
        echo "Usage: ./build.sh [command]"
        echo ""
        echo "Commands:"
        echo "  build          - Build the ISO (default)"
        echo "  test           - Test ISO in QEMU (graphical)"
        echo "  test-nographic - Test ISO in QEMU (text mode)"
        echo "  clean          - Remove build artifacts"
        ;;
esac
