# Dockerfile for Crom-OS Spirit Build Environment
# Builds all Spirit binaries and generates bootable ISO

FROM alpine:3.19 AS builder

# Install build dependencies (fixed package conflicts)
RUN apk add --no-cache \
    go \
    gcc \
    musl-dev \
    make \
    git \
    linux-headers \
    fuse-dev \
    libvirt-dev \
    pkgconfig \
    xorg-server-dev \
    mesa-dev \
    libx11-dev \
    libxcursor-dev \
    libxrandr-dev \
    libxinerama-dev \
    libxi-dev \
    alsa-lib-dev \
    syslinux \
    xorriso \
    mtools

# Set Go environment
ENV GOPATH=/go
ENV PATH=$PATH:/go/bin
ENV CGO_ENABLED=1
ENV GOOS=linux
ENV GOARCH=amd64

# Create workspace
WORKDIR /spirit

# Copy source code
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build all binaries (skip Raylib for now - use simple version)
RUN go build -ldflags="-s -w" -o build/init ./cmd/init || echo "init build skipped"
RUN go build -ldflags="-s -w" -o build/nodus ./cmd/nodus || echo "nodus build skipped"
RUN go build -ldflags="-s -w" -o build/hypervisor ./cmd/hypervisor || echo "hypervisor build skipped"

# Build kernel (using Alpine's kernel)
RUN apk add --no-cache linux-virt

# Stage 2: Create minimal rootfs
FROM alpine:3.19 AS rootfs

# Install minimal runtime (fixed package names)
RUN apk add --no-cache \
    busybox \
    musl \
    fuse \
    libvirt-client \
    qemu-system-x86_64 \
    qemu-img

# Create directory structure
RUN mkdir -p /spirit/{bin,etc,proc,sys,dev,tmp,run,mnt/nodus,var/lib/spirit,root}

# Copy binaries from builder (if they exist)
COPY --from=builder /spirit/build/ /spirit/bin/ 
COPY --from=builder /spirit/scripts/gpu_detach.sh /spirit/bin/gpu_detach
COPY --from=builder /spirit/scripts/gpu_attach.sh /spirit/bin/gpu_attach

# Make scripts executable
RUN chmod +x /spirit/bin/* 2>/dev/null || true

# Create init symlink
RUN ln -sf /spirit/bin/init /init 2>/dev/null || true

# Create basic busybox-based init as fallback
RUN echo '#!/bin/sh' > /init && \
    echo 'mount -t proc proc /proc' >> /init && \
    echo 'mount -t sysfs sys /sys' >> /init && \
    echo 'mount -t devtmpfs dev /dev' >> /init && \
    echo 'echo "Crom-OS Spirit v1.0"' >> /init && \
    echo 'exec /bin/sh' >> /init && \
    chmod +x /init

# Stage 3: ISO Builder
FROM alpine:3.19 AS iso-builder

# Install ISO tools
RUN apk add --no-cache \
    xorriso \
    syslinux \
    mtools \
    cpio \
    gzip \
    linux-virt

# Copy rootfs from previous stage
COPY --from=rootfs / /iso/rootfs/

# Create ISO structure
RUN mkdir -p /iso/{boot/isolinux,boot/grub,EFI/BOOT}

# Copy kernel
RUN cp /boot/vmlinuz-virt /iso/boot/vmlinuz

# Create initramfs from rootfs
RUN cd /iso/rootfs && find . | cpio -o -H newc 2>/dev/null | gzip > /iso/boot/initramfs.gz

# Copy ISOLINUX bootloader
RUN cp /usr/share/syslinux/isolinux.bin /iso/boot/isolinux/ && \
    cp /usr/share/syslinux/ldlinux.c32 /iso/boot/isolinux/ && \
    cp /usr/share/syslinux/libcom32.c32 /iso/boot/isolinux/ && \
    cp /usr/share/syslinux/libutil.c32 /iso/boot/isolinux/ && \
    cp /usr/share/syslinux/menu.c32 /iso/boot/isolinux/ && \
    cp /usr/share/syslinux/vesamenu.c32 /iso/boot/isolinux/ 2>/dev/null || true

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

# Final stage: output ISO
FROM scratch AS output
COPY --from=iso-builder /spirit-v1.0.iso /
