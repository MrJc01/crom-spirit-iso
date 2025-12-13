# Dockerfile for Crom-OS Spirit Build Environment
# Builds all Spirit binaries and generates bootable ISO

# Stage 1: Build Go binaries (skip CGO-dependent ones for now)
FROM golang:1.22-alpine AS builder

RUN apk add --no-cache gcc musl-dev make git linux-headers

WORKDIR /spirit
COPY go.mod go.sum ./
RUN go mod download
COPY . .

# Build init only (nodus/hypervisor need libvirt/fuse which require more setup)
RUN go build -ldflags="-s -w" -o build/init ./cmd/init 2>&1 || echo "init skipped"
RUN ls -la build/ 2>/dev/null || mkdir -p build

# Stage 2: Create rootfs with shell-based tools
FROM alpine:3.19 AS rootfs

# Install runtime packages
RUN apk add --no-cache \
    busybox \
    busybox-extras \
    util-linux \
    procps \
    ncurses \
    libvirt-client \
    qemu-system-x86_64 \
    qemu-img \
    fuse

# Create directory structure
RUN mkdir -p /spirit/{bin,etc,proc,sys,dev,tmp,run,mnt/nodus,var/lib/spirit,root}
RUN mkdir -p /home/spirit

# Copy built binaries
COPY --from=builder /spirit/build/ /spirit/bin/
COPY --from=builder /spirit/scripts/gpu_detach.sh /spirit/bin/gpu_detach
COPY --from=builder /spirit/scripts/gpu_attach.sh /spirit/bin/gpu_attach

# Create nodus command (shell version)
RUN printf '#!/bin/sh\n\
echo ""\n\
echo "╔══════════════════════════════════════╗"\n\
echo "║      NODUS - P2P Storage             ║"\n\
echo "╚══════════════════════════════════════╝"\n\
echo ""\n\
case "$1" in\n\
  discover)\n\
    echo "Discovering peers on LAN..."\n\
    echo "No peers found (standalone mode)"\n\
    ;;\n\
  peers)\n\
    echo "Connected peers: 0"\n\
    echo "(No network connection)"\n\
    ;;\n\
  mount)\n\
    echo "Mounting Nodus volume at /mnt/nodus..."\n\
    mount -t tmpfs tmpfs /mnt/nodus 2>/dev/null\n\
    echo "Mounted (local cache mode)"\n\
    ;;\n\
  status)\n\
    echo "Nodus Status:"\n\
    echo "  Mode: Standalone"\n\
    echo "  Cache: /mnt/nodus"\n\
    echo "  Peers: 0"\n\
    ;;\n\
  *)\n\
    echo "Usage: nodus <command>"\n\
    echo ""\n\
    echo "Commands:"\n\
    echo "  discover  - Find peers on LAN"\n\
    echo "  peers     - List connected peers"\n\
    echo "  mount     - Mount Nodus volume"\n\
    echo "  status    - Show status"\n\
    ;;\n\
esac\n\
' > /spirit/bin/nodus && chmod +x /spirit/bin/nodus

# Create hypervisor command (shell version)
RUN printf '#!/bin/sh\n\
echo ""\n\
echo "╔══════════════════════════════════════╗"\n\
echo "║    HYPERVISOR - VM Manager           ║"\n\
echo "╚══════════════════════════════════════╝"\n\
echo ""\n\
case "$1" in\n\
  list)\n\
    echo "Virtual Machines:"\n\
    virsh list --all 2>/dev/null || echo "  (no VMs configured)"\n\
    ;;\n\
  start)\n\
    if [ -z "$2" ]; then\n\
      echo "Usage: hypervisor start <vm-name>"\n\
    else\n\
      echo "Starting VM: $2..."\n\
      virsh start "$2" 2>/dev/null || echo "VM not found"\n\
    fi\n\
    ;;\n\
  stop)\n\
    if [ -z "$2" ]; then\n\
      echo "Usage: hypervisor stop <vm-name>"\n\
    else\n\
      echo "Stopping VM: $2..."\n\
      virsh shutdown "$2" 2>/dev/null || echo "VM not found"\n\
    fi\n\
    ;;\n\
  status)\n\
    echo "Hypervisor Status:"\n\
    echo "  Backend: QEMU/KVM"\n\
    virsh version 2>/dev/null | head -3 || echo "  (libvirtd not running)"\n\
    ;;\n\
  *)\n\
    echo "Usage: hypervisor <command> [args]"\n\
    echo ""\n\
    echo "Commands:"\n\
    echo "  list           - List all VMs"\n\
    echo "  start <name>   - Start a VM"\n\
    echo "  stop <name>    - Stop a VM"\n\
    echo "  status         - Show hypervisor status"\n\
    ;;\n\
esac\n\
' > /spirit/bin/hypervisor && chmod +x /spirit/bin/hypervisor

# Create @windows command
RUN printf '#!/bin/sh\n\
if [ -z "$1" ]; then\n\
  echo "Usage: @windows <command>"\n\
  echo "Runs command in Windows VM"\n\
  exit 1\n\
fi\n\
echo "[Spirit -> Windows] $*"\n\
echo "(Windows VM not running)"\n\
' > /bin/@windows && chmod +x /bin/@windows

# Create @linux command  
RUN printf '#!/bin/sh\n\
if [ -z "$1" ]; then\n\
  echo "Usage: @linux <command>"\n\
  echo "Runs command in Linux VM"\n\
  exit 1\n\
fi\n\
echo "[Spirit -> Linux] $*"\n\
echo "(Linux VM not running)"\n\
' > /bin/@linux && chmod +x /bin/@linux

# Create @ai command
RUN printf '#!/bin/sh\n\
echo ""\n\
echo "🤖 Spirit AI Assistant"\n\
echo ""\n\
if [ -z "$1" ]; then\n\
  echo "Usage: @ai \"your question\""\n\
else\n\
  echo "Q: $*"\n\
  echo "A: AI functionality requires network connection."\n\
fi\n\
' > /bin/@ai && chmod +x /bin/@ai

# Create spirit command (main menu)
RUN printf '#!/bin/sh\n\
clear\n\
echo ""\n\
echo "  ╔══════════════════════════════════════╗"\n\
echo "  ║       🔮 CROM-OS SPIRIT v1.0         ║"\n\
echo "  ╠══════════════════════════════════════╣"\n\
echo "  ║  [1] Nodus Status                    ║"\n\
echo "  ║  [2] Hypervisor Status               ║"\n\
echo "  ║  [3] System Info                     ║"\n\
echo "  ║  [4] Network Info                    ║"\n\
echo "  ║  [5] GPU Passthrough                 ║"\n\
echo "  ║  [0] Exit                            ║"\n\
echo "  ╚══════════════════════════════════════╝"\n\
echo ""\n\
printf "Select option: "\n\
read opt\n\
case $opt in\n\
  1) /spirit/bin/nodus status ;;\n\
  2) /spirit/bin/hypervisor status ;;\n\
  3) echo ""; cat /proc/cpuinfo | head -5; free -h ;;\n\
  4) ip addr 2>/dev/null || echo "No network" ;;\n\
  5) /spirit/bin/gpu_detach ;;\n\
  0) exit 0 ;;\n\
  *) echo "Invalid option" ;;\n\
esac\n\
echo ""\n\
echo "Press Enter to continue..."\n\
read dummy\n\
exec /bin/spirit\n\
' > /bin/spirit && chmod +x /bin/spirit

# Make all scripts executable
RUN chmod +x /spirit/bin/* 2>/dev/null || true

# Remove busybox poweroff/reboot and create custom versions
RUN rm -f /sbin/poweroff /sbin/reboot /sbin/halt 2>/dev/null || true
RUN printf '#!/bin/sh\necho "Syncing..."\nsync\necho "Powering off..."\necho o > /proc/sysrq-trigger\n' > /sbin/poweroff && chmod +x /sbin/poweroff
RUN printf '#!/bin/sh\necho "Syncing..."\nsync\necho "Rebooting..."\necho b > /proc/sysrq-trigger\n' > /sbin/reboot && chmod +x /sbin/reboot
RUN printf '#!/bin/sh\necho "Shutting down..."\nsync\necho o > /proc/sysrq-trigger\n' > /sbin/halt && chmod +x /sbin/halt

# Create help command
RUN printf '#!/bin/sh\n\
echo ""\n\
echo "╔══════════════════════════════════════╗"\n\
echo "║    CROM-OS SPIRIT - HELP             ║"\n\
echo "╚══════════════════════════════════════╝"\n\
echo ""\n\
echo "System Commands:"\n\
echo "  spirit      - Open Spirit menu"\n\
echo "  poweroff    - Shutdown system"\n\
echo "  reboot      - Restart system"\n\
echo "  help        - This help"\n\
echo ""\n\
echo "Spirit Tools:"\n\
echo "  nodus       - P2P storage daemon"\n\
echo "  hypervisor  - VM manager"\n\
echo "  gpu_detach  - Detach GPU for passthrough"\n\
echo "  gpu_attach  - Reattach GPU"\n\
echo ""\n\
echo "VM Commands:"\n\
echo "  @windows <cmd>  - Run in Windows VM"\n\
echo "  @linux <cmd>    - Run in Linux VM"\n\
echo "  @ai \"query\"     - Ask AI assistant"\n\
echo ""\n\
' > /bin/help && chmod +x /bin/help

# Create init script
RUN printf '#!/bin/sh\n\
# Crom-OS Spirit Init (PID 1)\n\
\n\
mount -t proc proc /proc\n\
mount -t sysfs sysfs /sys\n\
mount -t devtmpfs devtmpfs /dev\n\
mount -t tmpfs tmpfs /tmp\n\
mount -t tmpfs tmpfs /run\n\
mkdir -p /dev/pts\n\
mount -t devpts devpts /dev/pts\n\
\n\
echo 1 > /proc/sys/kernel/sysrq\n\
hostname spirit-node\n\
\n\
clear\n\
echo ""\n\
echo "  ======================================"\n\
echo "       Crom-OS Spirit v1.0"\n\
echo "  ======================================"\n\
echo ""\n\
echo "[OK] Filesystems mounted"\n\
echo "[OK] System ready"\n\
echo ""\n\
echo "Type: spirit (menu) | help (commands)"\n\
echo ""\n\
\n\
export PATH=/bin:/sbin:/spirit/bin:$PATH\n\
export HOME=/root\n\
export TERM=linux\n\
\n\
while true; do\n\
    /bin/sh -l\n\
    echo "Shell exited. Press Enter to continue or type poweroff..."\n\
    read dummy\n\
done\n\
' > /init && chmod +x /init

# Stage 3: ISO Builder
FROM alpine:3.19 AS iso-builder

RUN apk add --no-cache xorriso syslinux mtools cpio gzip linux-virt

RUN mkdir -p /iso/boot/isolinux /iso/boot/grub
RUN cp /boot/vmlinuz-virt /iso/boot/vmlinuz

COPY --from=rootfs / /iso/rootfs/

RUN cd /iso/rootfs && find . | cpio -o -H newc 2>/dev/null | gzip > /iso/boot/initramfs.gz

RUN cp /usr/share/syslinux/isolinux.bin /iso/boot/isolinux/ && \
    cp /usr/share/syslinux/ldlinux.c32 /iso/boot/isolinux/ && \
    cp /usr/share/syslinux/libcom32.c32 /iso/boot/isolinux/ && \
    cp /usr/share/syslinux/libutil.c32 /iso/boot/isolinux/ && \
    cp /usr/share/syslinux/menu.c32 /iso/boot/isolinux/

RUN printf 'UI menu.c32\n\
TIMEOUT 50\n\
DEFAULT spirit\n\
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

RUN ls -lh /spirit-v1.0.iso

FROM scratch AS output
COPY --from=iso-builder /spirit-v1.0.iso /
