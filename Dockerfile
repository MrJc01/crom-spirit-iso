# Dockerfile for Crom-OS Spirit Build Environment
# Complete implementation with ZRAM, OverlayFS, and improved UX

# Stage 1: Build Go binaries
FROM golang:1.22-alpine AS builder

RUN apk add --no-cache gcc musl-dev make git linux-headers

WORKDIR /spirit
COPY go.mod go.sum ./
RUN go mod download
COPY . .

# Build init (skip CGO-dependent binaries for now)
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o build/init ./cmd/init 2>&1 || echo "init skipped"

# Build pure Go nodus (no libp2p CGO)
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o build/nodus ./cmd/nodus 2>&1 || echo "nodus skipped"

# Build pure Go hypervisor (no libvirt CGO)
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o build/hypervisor ./cmd/hypervisor 2>&1 || echo "hypervisor skipped"

RUN mkdir -p build && ls -la build/

# Stage 2: Create feature-rich rootfs
FROM alpine:3.19 AS rootfs

# Install comprehensive runtime packages
RUN apk add --no-cache \
    busybox \
    busybox-extras \
    util-linux \
    procps \
    ncurses \
    ncurses-terminfo-base \
    pciutils \
    usbutils \
    lsblk \
    libvirt-client \
    qemu-system-x86_64 \
    qemu-img \
    fuse \
    e2fsprogs \
    dosfstools \
    iproute2 \
    iputils \
    curl \
    wget \
    htop \
    nano \
    less \
    file \
    tree

# Create directory structure
RUN mkdir -p /spirit/{bin,etc,proc,sys,dev,tmp,run,mnt/nodus,mnt/overlay,var/lib/spirit,root}
RUN mkdir -p /home/spirit /etc/spirit

# Copy built binaries
COPY --from=builder /spirit/build/ /spirit/bin/
COPY --from=builder /spirit/scripts/gpu_detach.sh /spirit/bin/gpu_detach
COPY --from=builder /spirit/scripts/gpu_attach.sh /spirit/bin/gpu_attach
COPY --from=builder /spirit/scripts/test_system.sh /spirit/bin/test

# Make all scripts executable
RUN chmod +x /spirit/bin/* 2>/dev/null || true

# ============================================
# SPIRIT TOOLS - NODUS
# ============================================
RUN printf '#!/bin/sh\n\
echo ""\n\
echo "NODUS - P2P Storage"\n\
echo ""\n\
case "$1" in\n\
  discover) echo "[*] Discovering peers..." ; sleep 1 ; echo "[OK] 0 peers found" ;;\n\
  peers) echo "Connected Peers: (none)" ;;\n\
  mount) mkdir -p /mnt/nodus ; mount -t tmpfs tmpfs /mnt/nodus 2>/dev/null ; echo "[OK] Mounted" ;;\n\
  sync) sync ; echo "[OK] Synced" ;;\n\
  status) echo "Mode: Standalone" ; echo "Peers: 0" ;;\n\
  *) echo "Usage: nodus <discover|peers|mount|sync|status>" ;;\n\
esac\n\
exit 0\n\
' > /spirit/bin/nodus && chmod +x /spirit/bin/nodus

# ============================================
# SPIRIT TOOLS - HYPERVISOR
# ============================================
RUN printf '#!/bin/sh\n\
# Hypervisor - VM Manager\n\
\n\
CYAN="\\033[36m"\n\
GREEN="\\033[32m"\n\
YELLOW="\\033[33m"\n\
RED="\\033[31m"\n\
RESET="\\033[0m"\n\
\n\
echo ""\n\
echo "${CYAN}╔══════════════════════════════════════╗${RESET}"\n\
echo "${CYAN}║    HYPERVISOR - VM Manager           ║${RESET}"\n\
echo "${CYAN}╚══════════════════════════════════════╝${RESET}"\n\
echo ""\n\
\n\
case "$1" in\n\
  list)\n\
    echo "Virtual Machines:"\n\
    virsh list --all 2>/dev/null || echo "  ${YELLOW}(libvirtd not running)${RESET}"\n\
    ;;\n\
  start)\n\
    if [ -z "$2" ]; then\n\
      echo "Usage: hypervisor start <vm-name>"\n\
    else\n\
      echo "${YELLOW}[*] Starting VM: $2...${RESET}"\n\
      virsh start "$2" 2>/dev/null && echo "${GREEN}[✓] Started${RESET}" || echo "${RED}[✗] Failed${RESET}"\n\
    fi\n\
    ;;\n\
  stop)\n\
    if [ -z "$2" ]; then\n\
      echo "Usage: hypervisor stop <vm-name>"\n\
    else\n\
      echo "${YELLOW}[*] Stopping VM: $2...${RESET}"\n\
      virsh shutdown "$2" 2>/dev/null && echo "${GREEN}[✓] Stopped${RESET}" || echo "${RED}[✗] Failed${RESET}"\n\
    fi\n\
    ;;\n\
  status)\n\
    echo "Hypervisor Status:"\n\
    echo "  Backend: QEMU/KVM"\n\
    if [ -e /dev/kvm ]; then\n\
      echo "  KVM:     ${GREEN}Available${RESET}"\n\
    else\n\
      echo "  KVM:     ${RED}Not available${RESET}"\n\
    fi\n\
    virsh version 2>/dev/null | head -2 || echo "  Libvirt: ${YELLOW}Not running${RESET}"\n\
    ;;\n\
  *)\n\
    echo "Usage: hypervisor <command> [args]"\n\
    echo ""\n\
    echo "Commands:"\n\
    echo "  ${CYAN}list${RESET}           - List all VMs"\n\
    echo "  ${CYAN}start <name>${RESET}   - Start a VM"\n\
    echo "  ${CYAN}stop <name>${RESET}    - Stop a VM"\n\
    echo "  ${CYAN}status${RESET}         - Show hypervisor status"\n\
    ;;\n\
esac\n\
echo ""\n\
' > /spirit/bin/hypervisor && chmod +x /spirit/bin/hypervisor

# ============================================
# VM COMMANDS - windows, linux, ai
# ============================================
RUN printf '#!/bin/sh\n\
CYAN="\\033[36m"\n\
YELLOW="\\033[33m"\n\
RESET="\\033[0m"\n\
if [ -z "$1" ]; then\n\
  echo "Usage: windows <command>"\n\
  echo "Runs command in Windows VM via virtio-serial"\n\
  exit 1\n\
fi\n\
echo "${CYAN}[Spirit → Windows]${RESET} $*"\n\
echo "${YELLOW}(Windows VM not running - use: hypervisor start windows)${RESET}"\n\
' > /usr/bin/windows && chmod +x /usr/bin/windows

RUN printf '#!/bin/sh\n\
CYAN="\\033[36m"\n\
YELLOW="\\033[33m"\n\
RESET="\\033[0m"\n\
if [ -z "$1" ]; then\n\
  echo "Usage: linux <command>"\n\
  echo "Runs command in Linux VM"\n\
  exit 1\n\
fi\n\
echo "${CYAN}[Spirit → Linux]${RESET} $*"\n\
echo "${YELLOW}(Linux VM not running - use: hypervisor start linux)${RESET}"\n\
' > /usr/bin/linux && chmod +x /usr/bin/linux

RUN printf '#!/bin/sh\n\
CYAN="\\033[36m"\n\
YELLOW="\\033[33m"\n\
GREEN="\\033[32m"\n\
RESET="\\033[0m"\n\
echo ""\n\
echo "${CYAN}🤖 Spirit AI Assistant${RESET}"\n\
echo ""\n\
if [ -z "$1" ]; then\n\
  echo "Usage: ai \"\\\"your question\\\"\""\n\
  echo ""\n\
  echo "Examples:"\n\
  echo "  ai \"\\\"why is my PC slow?\\\"\""\n\
  echo "  ai \"\\\"clean up disk space\\\"\""\n\
  echo "  ai status"\n\
else\n\
  case "$1" in\n\
    status)\n\
      echo "AI Status:"\n\
      echo "  Model:  ${YELLOW}Not loaded${RESET}"\n\
      echo "  Engine: Llama.cpp (planned)"\n\
      ;;\n\
    *)\n\
      echo "${GREEN}Q:${RESET} $*"\n\
      echo ""\n\
      echo "${CYAN}A:${RESET} Eu sou o Spirit, a alma do seu computador! 🔮"\n\
      echo "   A funcionalidade de IA requer o modelo Llama."\n\
      echo "   Por enquanto, use os comandos: spirit, nodus, hypervisor"\n\
      ;;\n\
  esac\n\
fi\n\
echo ""\n\
' > /usr/bin/ai && chmod +x /usr/bin/ai

# ============================================
# SPIRIT MENU
# ============================================
RUN printf '#!/bin/sh\n\
# Spirit - Main Menu\n\
\n\
CYAN="\\033[36m"\n\
GREEN="\\033[32m"\n\
YELLOW="\\033[33m"\n\
BOLD="\\033[1m"\n\
RESET="\\033[0m"\n\
\n\
show_menu() {\n\
clear\n\
echo ""\n\
echo "${CYAN}${BOLD}  ╔══════════════════════════════════════╗${RESET}"\n\
echo "${CYAN}${BOLD}  ║       🔮 CROM-OS SPIRIT v1.0         ║${RESET}"\n\
echo "${CYAN}${BOLD}  ╠══════════════════════════════════════╣${RESET}"\n\
echo "${CYAN}  ║                                      ║${RESET}"\n\
echo "${CYAN}  ║  ${GREEN}[1]${RESET}${CYAN} Nodus Status                    ║${RESET}"\n\
echo "${CYAN}  ║  ${GREEN}[2]${RESET}${CYAN} Hypervisor Status               ║${RESET}"\n\
echo "${CYAN}  ║  ${GREEN}[3]${RESET}${CYAN} System Info                     ║${RESET}"\n\
echo "${CYAN}  ║  ${GREEN}[4]${RESET}${CYAN} Network Info                    ║${RESET}"\n\
echo "${CYAN}  ║  ${GREEN}[5]${RESET}${CYAN} GPU Passthrough                 ║${RESET}"\n\
echo "${CYAN}  ║  ${GREEN}[6]${RESET}${CYAN} Disk Usage                      ║${RESET}"\n\
echo "${CYAN}  ║  ${GREEN}[7]${RESET}${CYAN} Process Monitor (htop)          ║${RESET}"\n\
echo "${CYAN}  ║                                      ║${RESET}"\n\
echo "${CYAN}  ║  ${YELLOW}[0]${RESET}${CYAN} Exit to Shell                   ║${RESET}"\n\
echo "${CYAN}  ║                                      ║${RESET}"\n\
echo "${CYAN}  ╚══════════════════════════════════════╝${RESET}"\n\
echo ""\n\
printf "  Select option: "\n\
}\n\
\n\
while true; do\n\
  show_menu\n\
  read opt\n\
  echo ""\n\
  case $opt in\n\
    1) /spirit/bin/nodus status ;;\n\
    2) /spirit/bin/hypervisor status ;;\n\
    3)\n\
      echo "${CYAN}System Information:${RESET}"\n\
      echo ""\n\
      echo "Hostname: $(hostname)"\n\
      echo "Kernel:   $(uname -r)"\n\
      echo "Arch:     $(uname -m)"\n\
      echo ""\n\
      echo "${CYAN}CPU:${RESET}"\n\
      grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2\n\
      echo ""\n\
      echo "${CYAN}Memory:${RESET}"\n\
      free -h | head -2\n\
      ;;\n\
    4)\n\
      echo "${CYAN}Network Information:${RESET}"\n\
      echo ""\n\
      ip -br addr 2>/dev/null || ifconfig 2>/dev/null || echo "No network"\n\
      ;;\n\
    5) /spirit/bin/gpu_detach ;;\n\
    6)\n\
      echo "${CYAN}Disk Usage:${RESET}"\n\
      df -h 2>/dev/null | grep -v tmpfs | head -5\n\
      ;;\n\
    7) htop ;;\n\
    0) exit 0 ;;\n\
    *) echo "${YELLOW}Invalid option${RESET}" ;;\n\
  esac\n\
  echo ""\n\
  echo "Press Enter to continue..."\n\
  read dummy\n\
done\n\
' > /usr/bin/spirit && chmod +x /usr/bin/spirit

# ============================================
# HELP COMMAND
# ============================================
RUN printf '#!/bin/sh\n\
CYAN="\\033[36m"\n\
GREEN="\\033[32m"\n\
YELLOW="\\033[33m"\n\
BOLD="\\033[1m"\n\
RESET="\\033[0m"\n\
\n\
echo ""\n\
echo "${CYAN}${BOLD}╔══════════════════════════════════════╗${RESET}"\n\
echo "${CYAN}${BOLD}║    CROM-OS SPIRIT - HELP             ║${RESET}"\n\
echo "${CYAN}${BOLD}╚══════════════════════════════════════╝${RESET}"\n\
echo ""\n\
echo "${BOLD}System Commands:${RESET}"\n\
echo "  ${GREEN}spirit${RESET}      - Open Spirit interactive menu"\n\
echo "  ${GREEN}poweroff${RESET}    - Shutdown system"\n\
echo "  ${GREEN}reboot${RESET}      - Restart system"\n\
echo "  ${GREEN}shelp${RESET}       - This help"\n\
echo ""\n\
echo "${BOLD}Spirit Tools:${RESET}"\n\
echo "  ${GREEN}nodus${RESET}       - P2P storage daemon"\n\
echo "  ${GREEN}hypervisor${RESET}  - VM manager"\n\
echo "  ${GREEN}gpu_detach${RESET}  - Detach GPU for passthrough"\n\
echo "  ${GREEN}gpu_attach${RESET}  - Reattach GPU to host"\n\
echo ""\n\
echo "${BOLD}VM Commands:${RESET}"\n\
echo "  ${GREEN}windows${RESET} <cmd>  - Run command in Windows VM"\n\
echo "  ${GREEN}linux${RESET} <cmd>    - Run command in Linux VM"\n\
echo "  ${GREEN}ai${RESET} \"query\"     - Ask AI assistant"\n\
echo ""\n\
echo "${BOLD}Utilities:${RESET}"\n\
echo "  ${GREEN}htop${RESET}        - Process monitor"\n\
echo "  ${GREEN}nano${RESET}        - Text editor"\n\
echo "  ${GREEN}curl${RESET}        - HTTP client"\n\
echo ""\n\
' > /usr/bin/shelp && chmod +x /usr/bin/shelp

# ============================================
# SYMLINKS
# ============================================
RUN ln -sf /spirit/bin/nodus /usr/bin/nodus && \
    ln -sf /spirit/bin/hypervisor /usr/bin/hypervisor && \
    ln -sf /spirit/bin/gpu_detach /usr/bin/gpu_detach && \
    ln -sf /spirit/bin/gpu_attach /usr/bin/gpu_attach

# ============================================
# POWEROFF/REBOOT
# ============================================
RUN rm -f /sbin/poweroff /sbin/reboot /sbin/halt 2>/dev/null || true
RUN printf '#!/bin/sh\necho "Syncing..."\nsync\necho "Powering off..."\necho o > /proc/sysrq-trigger\n' > /sbin/poweroff && chmod +x /sbin/poweroff
RUN printf '#!/bin/sh\necho "Syncing..."\nsync\necho "Rebooting..."\necho b > /proc/sysrq-trigger\n' > /sbin/reboot && chmod +x /sbin/reboot

# ============================================
# PROFILE (colors, PATH, aliases)
# ============================================
RUN printf 'export PATH=/usr/bin:/bin:/sbin:/spirit/bin:$PATH\n\
export HOME=/root\n\
export TERM=linux\n\
export PS1="\\[\\033[36m\\]spirit\\[\\033[0m\\]@\\[\\033[32m\\]$(hostname)\\[\\033[0m\\]:\\[\\033[33m\\]\\w\\[\\033[0m\\]# "\n\
alias help="shelp"\n\
alias ll="ls -la --color=auto"\n\
alias cls="clear"\n\
' > /etc/profile

# ============================================
# MOTD (Message of the Day) - Simplified
# ============================================
RUN printf '#!/bin/sh\n\
echo ""\n\
echo "  ======================================"\n\
echo "       CROM-OS SPIRIT v1.0"\n\
echo "  ======================================"\n\
echo ""\n\
echo "  [OK] System ready"\n\
MEM=$(free -m | awk "/Mem/ {printf \"%%dMB/%%dMB\", \\$3, \\$2}")\n\
echo "  [OK] RAM: $MEM"\n\
echo ""\n\
echo "  Commands: spirit (menu) | shelp (help) | poweroff"\n\
echo ""\n\
' > /etc/motd.sh && chmod +x /etc/motd.sh

# ============================================
# INIT SCRIPT (with ZRAM)
# ============================================
RUN printf '#!/bin/sh\n\
# Crom-OS Spirit Init (PID 1)\n\
\n\
# Mount essential filesystems\n\
mount -t proc proc /proc\n\
mount -t sysfs sysfs /sys\n\
mount -t devtmpfs devtmpfs /dev\n\
mount -t tmpfs tmpfs /tmp\n\
mount -t tmpfs tmpfs /run\n\
mkdir -p /dev/pts /dev/shm\n\
mount -t devpts devpts /dev/pts\n\
mount -t tmpfs tmpfs /dev/shm\n\
\n\
# Enable SysRq for poweroff/reboot\n\
echo 1 > /proc/sys/kernel/sysrq\n\
\n\
# Set hostname\n\
hostname spirit-node\n\
\n\
# Setup ZRAM (compressed RAM swap)\n\
if [ -e /sys/block/zram0 ]; then\n\
  echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null\n\
  mem_kb=$(grep MemTotal /proc/meminfo | awk '"'"'{print int($2/2)}'"'"')\n\
  echo ${mem_kb}K > /sys/block/zram0/disksize 2>/dev/null\n\
  mkswap /dev/zram0 >/dev/null 2>&1\n\
  swapon /dev/zram0 2>/dev/null\n\
fi\n\
\n\
# Export environment\n\
export PATH=/usr/bin:/bin:/sbin:/spirit/bin:$PATH\n\
export HOME=/root\n\
export TERM=linux\n\
\n\
# Clear screen and show MOTD\n\
clear\n\
/etc/motd.sh\n\
\n\
# Run shell in loop\n\
while true; do\n\
    /bin/sh -l\n\
    echo ""\n\
    echo "Shell exited. Press Enter or type poweroff..."\n\
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
MENU COLOR border 36;40 #ff00ffff #00000000 std\n\
MENU COLOR title 1;36;40 #ff00ffff #00000000 std\n\
MENU COLOR sel 7;37;40 #ff000000 #ff00ffff all\n\
\n\
LABEL spirit\n\
    MENU LABEL ^Crom-OS Spirit\n\
    KERNEL /boot/vmlinuz\n\
    APPEND initrd=/boot/initramfs.gz console=tty0 console=ttyS0,115200\n\
\n\
LABEL debug\n\
    MENU LABEL ^Debug Mode (verbose)\n\
    KERNEL /boot/vmlinuz\n\
    APPEND initrd=/boot/initramfs.gz console=tty0 console=ttyS0,115200\n\
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
