# Dockerfile for Crom-OS Spirit Build Environment
# Builds all Spirit binaries and generates bootable ISO

FROM alpine:3.19 AS builder

# Install build dependencies
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
    mtools \
    cdrkit

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

# Build all binaries
RUN make init nexus nodus hypervisor

# Build kernel (using Alpine's kernel)
RUN apk add --no-cache linux-virt

# Stage 2: Create minimal rootfs
FROM alpine:3.19 AS rootfs

# Install minimal runtime
RUN apk add --no-cache \
    busybox \
    musl \
    libfuse \
    libvirt-client \
    qemu-system-x86_64 \
    qemu-img

# Create directory structure
RUN mkdir -p /spirit/{bin,etc,proc,sys,dev,tmp,run,mnt/nodus,var/lib/spirit}

# Copy binaries from builder
COPY --from=builder /spirit/build/init /spirit/init
COPY --from=builder /spirit/build/nexus /spirit/bin/nexus
COPY --from=builder /spirit/build/nodus /spirit/bin/nodus
COPY --from=builder /spirit/build/hypervisor /spirit/bin/hypervisor
COPY --from=builder /spirit/scripts/gpu_detach.sh /spirit/bin/gpu_detach
COPY --from=builder /spirit/scripts/gpu_attach.sh /spirit/bin/gpu_attach

# Make scripts executable
RUN chmod +x /spirit/bin/*

# Create init symlink
RUN ln -sf /spirit/init /init

# Stage 3: ISO Builder
FROM builder AS iso-builder

# Copy rootfs
COPY --from=rootfs /spirit /iso/rootfs

# Create ISO structure
RUN mkdir -p /iso/{boot/isolinux,boot/grub,EFI/BOOT}

# Copy kernel and initramfs
RUN cp /boot/vmlinuz-virt /iso/boot/vmlinuz && \
    cd /iso/rootfs && find . | cpio -o -H newc | gzip > /iso/boot/initramfs.gz

# Copy ISOLINUX bootloader
RUN cp /usr/share/syslinux/isolinux.bin /iso/boot/isolinux/ && \
    cp /usr/share/syslinux/ldlinux.c32 /iso/boot/isolinux/ && \
    cp /usr/share/syslinux/libcom32.c32 /iso/boot/isolinux/ && \
    cp /usr/share/syslinux/libutil.c32 /iso/boot/isolinux/ && \
    cp /usr/share/syslinux/menu.c32 /iso/boot/isolinux/

# Create ISOLINUX config
RUN echo 'DEFAULT spirit\n\
TIMEOUT 30\n\
PROMPT 0\n\
\n\
MENU TITLE Crom-OS Spirit v1.0\n\
MENU COLOR border 30;44 #40ffffff #00000000 std\n\
MENU COLOR title 1;36;44 #c0ffffff #00000000 std\n\
MENU COLOR sel 7;37;40 #e0ffffff #20ffffff all\n\
MENU COLOR unsel 37;44 #50ffffff #00000000 std\n\
\n\
LABEL spirit\n\
    MENU LABEL ^Crom-OS Spirit (Normal Boot)\n\
    KERNEL /boot/vmlinuz\n\
    APPEND initrd=/boot/initramfs.gz quiet\n\
\n\
LABEL spirit-debug\n\
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
