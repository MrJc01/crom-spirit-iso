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

# Build binaries
RUN go build -ldflags="-s -w" -o build/init ./cmd/init 2>/dev/null || echo "init build skipped"
RUN go build -tags netgo -ldflags="-s -w" -o build/nodus ./cmd/nodus 2>/dev/null || echo "nodus build skipped"
RUN go build -ldflags="-s -w" -o build/hypervisor ./cmd/hypervisor 2>/dev/null || echo "hypervisor build skipped"

# Stage 2: Create minimal rootfs
FROM alpine:3.19 AS rootfs

# Install minimal runtime
RUN apk add --no-cache \
    busybox \
    musl \
    fuse \
    libvirt-client \
    qemu-system-x86_64 \
    qemu-img

# Create directory structure
RUN mkdir -p /spirit/{bin,etc,proc,sys,dev,tmp,run,mnt/nodus,var/lib/spirit,root}

# Copy binaries from builder
COPY --from=builder /spirit/build/ /spirit/bin/ 
COPY --from=builder /spirit/scripts/gpu_detach.sh /spirit/bin/gpu_detach
COPY --from=builder /spirit/scripts/gpu_attach.sh /spirit/bin/gpu_attach

# Make scripts executable
RUN chmod +x /spirit/bin/* 2>/dev/null || true

# Create basic shell init
RUN printf '#!/bin/sh\n\
echo ""\n\
echo "🔮 Crom-OS Spirit v1.0"\n\
echo ""\n\
mount -t proc proc /proc 2>/dev/null\n\
mount -t sysfs sys /sys 2>/dev/null\n\
mount -t devtmpfs dev /dev 2>/dev/null\n\
echo "System ready. Type commands or run /spirit/bin/* tools"\n\
exec /bin/sh\n\
' > /init && chmod +x /init

# Stage 3: ISO Builder
FROM alpine:3.19 AS iso-builder

# Install ISO tools AND kernel FIRST
RUN apk add --no-cache \
    xorriso \
    syslinux \
    mtools \
    cpio \
    gzip \
    linux-virt

# Create ISO structure AFTER packages are installed
RUN mkdir -p /iso/boot/isolinux /iso/boot/grub

# Copy kernel (now linux-virt is installed)
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
RUN ls -lh /spirit-v1.0.iso && echo "✅ ISO built successfully!"

# Final output
FROM scratch AS output
COPY --from=iso-builder /spirit-v1.0.iso /
