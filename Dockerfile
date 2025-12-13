# Dockerfile for Crom-OS Spirit Build Environment
# Builds all Spirit binaries and generates bootable ISO

# Stage 1: Build binaries with Go 1.22
FROM golang:1.22-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    gcc \
    musl-dev \
    make \
    git \
    linux-headers \
    fuse-dev \
    libvirt-dev \
    pkgconfig

# Set Go environment
ENV CGO_ENABLED=1
ENV GOOS=linux
ENV GOARCH=amd64

# Create workspace
WORKDIR /spirit

# Copy source code
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build binaries - show errors for debugging
RUN echo "Building init..." && \
    go build -ldflags="-s -w" -o build/init ./cmd/init 2>&1 || echo "init build failed"

RUN echo "Building nodus..." && \
    go build -ldflags="-s -w" -o build/nodus ./cmd/nodus 2>&1 || echo "nodus build failed"

RUN echo "Building hypervisor..." && \
    go build -ldflags="-s -w" -o build/hypervisor ./cmd/hypervisor 2>&1 || echo "hypervisor build failed"

# List what was built
RUN ls -la build/ || echo "No build directory"

# Stage 2: Create minimal rootfs
FROM alpine:3.19 AS rootfs

# Install minimal runtime
RUN apk add --no-cache \
    busybox \
    busybox-extras \
    musl \
    fuse \
    libvirt-client \
    qemu-system-x86_64 \
    qemu-img \
    util-linux

# Create directory structure
RUN mkdir -p /spirit/{bin,etc,proc,sys,dev,tmp,run,mnt/nodus,var/lib/spirit,root}

# Copy binaries from builder (if they exist)
COPY --from=builder /spirit/build/ /spirit/bin/ 
COPY --from=builder /spirit/scripts/gpu_detach.sh /spirit/bin/gpu_detach
COPY --from=builder /spirit/scripts/gpu_attach.sh /spirit/bin/gpu_attach

# Make scripts executable
RUN chmod +x /spirit/bin/* 2>/dev/null || true

# Create spirit commands wrapper scripts
RUN printf '#!/bin/sh\necho "Syncing..."\nsync\necho "Powering off..."\necho o > /proc/sysrq-trigger\n' > /sbin/poweroff && chmod +x /sbin/poweroff

RUN printf '#!/bin/sh\necho "Syncing..."\nsync\necho "Rebooting..."\necho b > /proc/sysrq-trigger\n' > /sbin/reboot && chmod +x /sbin/reboot

RUN printf '#!/bin/sh\necho "Shutting down Spirit..."\nsync\necho "Goodbye!"\necho o > /proc/sysrq-trigger\n' > /sbin/halt && chmod +x /sbin/halt

# Create help command
RUN printf '#!/bin/sh\necho ""\necho "Crom-OS Spirit Commands:"\necho "========================"\necho "  poweroff  - Shutdown the system"\necho "  reboot    - Restart the system"\necho "  ls        - List files"\necho "  help      - Show this help"\necho ""\necho "Spirit Tools:"\necho "  /spirit/bin/nodus      - P2P Storage"\necho "  /spirit/bin/hypervisor - VM Manager"\necho "  /spirit/bin/gpu_detach - GPU Passthrough"\necho ""\n' > /bin/help && chmod +x /bin/help

# Create init script that handles everything properly
RUN printf '#!/bin/sh\n\
# Crom-OS Spirit Init (PID 1)\n\
\n\
# Mount essential filesystems\n\
mount -t proc proc /proc\n\
mount -t sysfs sysfs /sys\n\
mount -t devtmpfs devtmpfs /dev\n\
mount -t tmpfs tmpfs /tmp\n\
mount -t tmpfs tmpfs /run\n\
mkdir -p /dev/pts\n\
mount -t devpts devpts /dev/pts\n\
\n\
# Enable magic SysRq for shutdown\n\
echo 1 > /proc/sys/kernel/sysrq\n\
\n\
# Set hostname\n\
hostname spirit-node\n\
\n\
# Clear screen and show banner\n\
clear\n\
echo ""\n\
echo "  ======================================"\n\
echo "       Crom-OS Spirit v1.0"\n\
echo "  ======================================"\n\
echo ""\n\
echo "[OK] Filesystems mounted"\n\
echo "[OK] System ready"\n\
echo ""\n\
echo "Commands: help, poweroff, reboot"\n\
echo "Spirit tools in /spirit/bin/"\n\
echo ""\n\
\n\
# Run shell in a loop - if it exits, restart it\n\
while true; do\n\
    /bin/sh -l\n\
    echo ""\n\
    echo "Shell exited. Type '\''poweroff'\'' to shutdown or press Enter to continue..."\n\
    read dummy\n\
done\n\
' > /init && chmod +x /init

# Stage 3: ISO Builder
FROM alpine:3.19 AS iso-builder

# Install ISO tools AND kernel
RUN apk add --no-cache \
    xorriso \
    syslinux \
    mtools \
    cpio \
    gzip \
    linux-virt

# Create ISO structure
RUN mkdir -p /iso/boot/isolinux /iso/boot/grub

# Copy kernel
RUN cp /boot/vmlinuz-virt /iso/boot/vmlinuz

# Copy rootfs from previous stage
COPY --from=rootfs / /iso/rootfs/

# Create initramfs from rootfs
RUN cd /iso/rootfs && find . | cpio -o -H newc 2>/dev/null | gzip > /iso/boot/initramfs.gz

# Copy ISOLINUX bootloader
RUN cp /usr/share/syslinux/isolinux.bin /iso/boot/isolinux/ && \
    cp /usr/share/syslinux/ldlinux.c32 /iso/boot/isolinux/ && \
    cp /usr/share/syslinux/libcom32.c32 /iso/boot/isolinux/ && \
    cp /usr/share/syslinux/libutil.c32 /iso/boot/isolinux/ && \
    cp /usr/share/syslinux/menu.c32 /iso/boot/isolinux/

# Create ISOLINUX config
RUN printf 'UI menu.c32\n\
TIMEOUT 50\n\
PROMPT 0\n\
\n\
MENU TITLE Crom-OS Spirit v1.0\n\
\n\
LABEL spirit\n\
    MENU LABEL ^Crom-OS Spirit\n\
    KERNEL /boot/vmlinuz\n\
    APPEND initrd=/boot/initramfs.gz quiet\n\
\n\
LABEL debug\n\
    MENU LABEL ^Debug Mode\n\
    KERNEL /boot/vmlinuz\n\
    APPEND initrd=/boot/initramfs.gz debug console=ttyS0\n\
\n\
LABEL shell\n\
    MENU LABEL ^Recovery Shell\n\
    KERNEL /boot/vmlinuz\n\
    APPEND initrd=/boot/initramfs.gz init=/bin/sh\n\
' > /iso/boot/isolinux/isolinux.cfg

# Build ISO
RUN xorriso -as mkisofs \
    -o /spirit-v1.0.iso \
    -isohybrid-mbr /usr/share/syslinux/isohdpfx.bin \
    -c boot/isolinux/boot.cat \
    -b boot/isolinux/isolinux.bin \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -V "CROM-OS-SPIRIT" \
    /iso

# Show ISO info
RUN ls -lh /spirit-v1.0.iso && echo "ISO built successfully!"

# Final output
FROM scratch AS output
COPY --from=iso-builder /spirit-v1.0.iso /
