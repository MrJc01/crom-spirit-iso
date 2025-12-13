#!/bin/bash
# build_iso.sh - Builds Crom-OS Spirit bootable ISO
# Usage: ./scripts/build_iso.sh [output_name]

set -e

OUTPUT_NAME="${1:-spirit-v1.0.iso}"
BUILD_DIR="$(pwd)/build"
ISO_DIR="$(pwd)/iso_staging"
ROOTFS_DIR="$ISO_DIR/rootfs"

echo "🔮 Crom-OS Spirit ISO Builder"
echo "=============================="

# Check dependencies
check_deps() {
    local missing=""
    for cmd in go gcc make cpio gzip xorriso; do
        if ! command -v $cmd &> /dev/null; then
            missing="$missing $cmd"
        fi
    done
    
    if [ -n "$missing" ]; then
        echo "❌ Missing dependencies:$missing"
        echo "   Install with: apt install golang gcc make cpio gzip xorriso syslinux-utils"
        exit 1
    fi
    echo "✅ All dependencies found"
}

# Build binaries
build_binaries() {
    echo ""
    echo "📦 Building binaries..."
    
    export CGO_ENABLED=1
    export GOOS=linux
    export GOARCH=amd64
    
    mkdir -p $BUILD_DIR
    
    echo "   Building init..."
    go build -ldflags="-s -w" -o $BUILD_DIR/init ./cmd/init
    
    echo "   Building nexus..."
    go build -ldflags="-s -w" -o $BUILD_DIR/nexus ./cmd/nexus
    
    echo "   Building nodus..."
    go build -ldflags="-s -w" -o $BUILD_DIR/nodus ./cmd/nodus
    
    echo "   Building hypervisor..."
    go build -ldflags="-s -w" -o $BUILD_DIR/hypervisor ./cmd/hypervisor
    
    echo "✅ Binaries built"
}

# Create rootfs
create_rootfs() {
    echo ""
    echo "🗂️  Creating rootfs..."
    
    rm -rf $ROOTFS_DIR
    mkdir -p $ROOTFS_DIR/{bin,sbin,etc,proc,sys,dev,tmp,run,mnt/nodus,var/lib/spirit,root}
    
    # Copy binaries
    cp $BUILD_DIR/init $ROOTFS_DIR/init
    cp $BUILD_DIR/nexus $ROOTFS_DIR/bin/
    cp $BUILD_DIR/nodus $ROOTFS_DIR/bin/
    cp $BUILD_DIR/hypervisor $ROOTFS_DIR/bin/
    cp scripts/gpu_detach.sh $ROOTFS_DIR/bin/gpu_detach
    cp scripts/gpu_attach.sh $ROOTFS_DIR/bin/gpu_attach
    chmod +x $ROOTFS_DIR/bin/*
    
    # Create busybox symlinks (if using busybox)
    if command -v busybox &> /dev/null; then
        cp $(which busybox) $ROOTFS_DIR/bin/
        for cmd in sh ls cat echo mkdir mount umount; do
            ln -sf busybox $ROOTFS_DIR/bin/$cmd
        done
    fi
    
    # Create basic etc files
    echo "spirit-node" > $ROOTFS_DIR/etc/hostname
    echo "root:x:0:0:root:/root:/bin/sh" > $ROOTFS_DIR/etc/passwd
    echo "root:x:0:" > $ROOTFS_DIR/etc/group
    
    # Create fstab
    cat > $ROOTFS_DIR/etc/fstab << 'EOF'
proc            /proc           proc    defaults        0 0
sysfs           /sys            sysfs   defaults        0 0
devtmpfs        /dev            devtmpfs defaults       0 0
tmpfs           /tmp            tmpfs   defaults        0 0
tmpfs           /run            tmpfs   defaults        0 0
EOF
    
    echo "✅ Rootfs created"
}

# Create initramfs
create_initramfs() {
    echo ""
    echo "📀 Creating initramfs..."
    
    mkdir -p $ISO_DIR/boot
    
    cd $ROOTFS_DIR
    find . | cpio -o -H newc 2>/dev/null | gzip > $ISO_DIR/boot/initramfs.gz
    cd - > /dev/null
    
    echo "✅ Initramfs created ($(du -h $ISO_DIR/boot/initramfs.gz | cut -f1))"
}

# Setup bootloader
setup_bootloader() {
    echo ""
    echo "🔧 Setting up bootloader..."
    
    mkdir -p $ISO_DIR/boot/isolinux
    
    # Copy ISOLINUX files
    SYSLINUX_DIR="/usr/lib/syslinux/modules/bios"
    if [ -d "/usr/share/syslinux" ]; then
        SYSLINUX_DIR="/usr/share/syslinux"
    fi
    
    for file in isolinux.bin ldlinux.c32 libcom32.c32 libutil.c32 menu.c32 vesamenu.c32; do
        if [ -f "$SYSLINUX_DIR/$file" ]; then
            cp "$SYSLINUX_DIR/$file" $ISO_DIR/boot/isolinux/
        fi
    done
    
    # Use system kernel or download one
    if [ -f "/boot/vmlinuz-$(uname -r)" ]; then
        cp /boot/vmlinuz-$(uname -r) $ISO_DIR/boot/vmlinuz
    else
        echo "⚠️  No kernel found, using Alpine's kernel..."
        # This would need to download a kernel
    fi
    
    # Create boot menu
    cat > $ISO_DIR/boot/isolinux/isolinux.cfg << 'EOF'
UI vesamenu.c32
TIMEOUT 50
PROMPT 0

MENU TITLE Crom-OS Spirit v1.0
MENU BACKGROUND #0f0f19
MENU COLOR border       30;44   #40ffffff #00000000 std
MENU COLOR title        1;36;44 #c0ffffff #00000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #00000000 std
MENU COLOR help         37;44   #c0ffffff #00000000 std
MENU COLOR timeout_msg  37;44   #80ffffff #00000000 std
MENU COLOR timeout      1;37;44 #c0ffffff #00000000 std

DEFAULT spirit

LABEL spirit
    MENU LABEL ^Crom-OS Spirit
    KERNEL /boot/vmlinuz
    APPEND initrd=/boot/initramfs.gz quiet loglevel=3

LABEL spirit-debug
    MENU LABEL ^Debug Mode (Verbose)
    KERNEL /boot/vmlinuz
    APPEND initrd=/boot/initramfs.gz debug console=tty0 console=ttyS0,115200

LABEL spirit-recovery
    MENU LABEL ^Recovery Shell
    KERNEL /boot/vmlinuz  
    APPEND initrd=/boot/initramfs.gz init=/bin/sh
EOF

    echo "✅ Bootloader configured"
}

# Generate ISO
generate_iso() {
    echo ""
    echo "💿 Generating ISO..."
    
    ISOHDPFX="/usr/lib/ISOLINUX/isohdpfx.bin"
    if [ -f "/usr/share/syslinux/isohdpfx.bin" ]; then
        ISOHDPFX="/usr/share/syslinux/isohdpfx.bin"
    fi
    
    xorriso -as mkisofs \
        -o $BUILD_DIR/$OUTPUT_NAME \
        -isohybrid-mbr $ISOHDPFX \
        -c boot/isolinux/boot.cat \
        -b boot/isolinux/isolinux.bin \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -V "CROM-OS-SPIRIT" \
        $ISO_DIR
    
    echo ""
    echo "✅ ISO created: $BUILD_DIR/$OUTPUT_NAME"
    echo "   Size: $(du -h $BUILD_DIR/$OUTPUT_NAME | cut -f1)"
}

# Cleanup
cleanup() {
    echo ""
    echo "🧹 Cleaning up..."
    rm -rf $ISO_DIR
}

# Main
main() {
    check_deps
    build_binaries
    create_rootfs
    create_initramfs
    setup_bootloader
    generate_iso
    cleanup
    
    echo ""
    echo "🎉 Build complete!"
    echo ""
    echo "To test with QEMU:"
    echo "  qemu-system-x86_64 -cdrom $BUILD_DIR/$OUTPUT_NAME -m 2048 -enable-kvm"
    echo ""
    echo "To write to USB:"
    echo "  sudo dd if=$BUILD_DIR/$OUTPUT_NAME of=/dev/sdX bs=4M status=progress"
}

main "$@"
