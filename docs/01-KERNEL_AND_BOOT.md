# 🔧 CROM-OS SPIRIT: Kernel & Boot Architecture

---

## 1. Kernel Foundation

### 1.1 Base System: Alpine Linux Custom

Crom-OS Spirit is built on a **stripped-down Alpine Linux** foundation, chosen for:

| Feature        | Alpine    | Debian           | Arch             |
| -------------- | --------- | ---------------- | ---------------- |
| Base Size      | ~5MB      | ~150MB           | ~200MB           |
| Init System    | OpenRC    | SystemD          | SystemD          |
| C Library      | musl      | glibc            | glibc            |
| Package Format | APK       | DEB              | Pkg              |
| RAM Boot Ready | ✅ Native | ❌ Requires work | ❌ Requires work |

> **Why Alpine?** musl libc produces smaller static binaries. OpenRC is lightweight and transparent. The distro was _designed_ for containers and RAM-based operation.

### 1.2 Kernel Configuration

```
# Spirit Kernel Essentials (.config excerpt)

# RAM-only operation
CONFIG_TMPFS=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_OVERLAY_FS=y

# Compression in RAM
CONFIG_ZRAM=y
CONFIG_ZRAM_WRITEBACK=n  # No writeback, RAM only
CONFIG_CRYPTO_LZ4=y
CONFIG_CRYPTO_ZSTD=y

# Virtualization (The Puppeteer)
CONFIG_KVM=y
CONFIG_KVM_INTEL=y
CONFIG_KVM_AMD=y
CONFIG_VFIO=y
CONFIG_VFIO_PCI=y

# Network Boot
CONFIG_IP_PNP=y
CONFIG_IP_PNP_DHCP=y
CONFIG_NFS_V4=y
CONFIG_ROOT_NFS=y

# Graphics (Minimal for Nexus)
CONFIG_DRM=y
CONFIG_DRM_KMS_HELPER=y
CONFIG_FB_EFI=y
CONFIG_FB_SIMPLE=y
```

### 1.3 Init System: Spirit-Init (Go Binary)

Instead of traditional init scripts, Spirit uses a custom Go-based init:

```go
// spirit-init.go (conceptual)
package main

import (
    "github.com/crom/spirit/nexus"
    "github.com/crom/spirit/nodus"
    "github.com/crom/spirit/overlay"
)

func main() {
    // Phase 1: Mount essential filesystems
    mountProc()
    mountSys()
    mountDev()

    // Phase 2: Setup memory overlay
    overlay.SetupZRAM(compressionLevel: "zstd")
    overlay.MountOverlayFS("/", "ram", "cloud")

    // Phase 3: Connect to network
    nodus.DiscoverPeers()
    nodus.MountRemoteStorage()

    // Phase 4: Launch interface
    nexus.Start()
}
```

---

## 2. Boot Process: The Cascade

The Spirit employs a **fallback cascade** to boot from any available source:

```
┌─────────────────────────────────────────────────────────────────┐
│                        BOOT CASCADE                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐                                               │
│  │ BIOS/UEFI    │                                               │
│  └──────┬───────┘                                               │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │            ATTEMPT 1: LOCAL PARASITE                      │   │
│  │  Check: C:\CromSpirit\kernel.zst exists?                  │   │
│  │  Yes → Load kernel from Windows partition                 │   │
│  │  No  → Continue cascade                                   │   │
│  └──────────────────────────────────────────────────────────┘   │
│         │ FAIL                                                   │
│         ▼                                                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │            ATTEMPT 2: USB SEED                            │   │
│  │  Check: USB device with CROM_SPIRIT label?                │   │
│  │  Yes → Boot from USB, stream remaining from net           │   │
│  │  No  → Continue cascade                                   │   │
│  └──────────────────────────────────────────────────────────┘   │
│         │ FAIL                                                   │
│         ▼                                                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │            ATTEMPT 3: HTTP BOOT (UEFI)                    │   │
│  │  URL: https://boot.crom.run/spirit/kernel.efi              │   │
│  │  Download kernel+initramfs directly from cloud            │   │
│  └──────────────────────────────────────────────────────────┘   │
│         │ FAIL (No UEFI HTTP or no internet)                     │
│         ▼                                                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │            ATTEMPT 4: CROM-NODUS LAN DISCOVERY            │   │
│  │  Broadcast: "CROM_SPIRIT_SEEK" on UDP 7331                │   │
│  │  Listen for: "CROM_SPIRIT_HERE:<IP>:<PORT>"               │   │
│  │  Connect to peer and stream kernel via NBD                │   │
│  └──────────────────────────────────────────────────────────┘   │
│         │ FAIL                                                   │
│         ▼                                                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │            FALLBACK: RESCUE SHELL                         │   │
│  │  Minimal BusyBox shell for diagnostics                    │   │
│  │  "No Spirit found. Awaiting network or media..."         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Boot Chain Detail

### 3.1 Complete Boot Sequence

```
┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐
│ BIOS   │───►│ iPXE   │───►│ Kernel │───►│ Init   │───►│ Nexus  │
│ POST   │    │ Chain  │    │ (RAM)  │    │ (Go)   │    │ (HUD)  │
└────────┘    └────────┘    └────────┘    └────────┘    └────────┘
   50ms          200ms          1s           500ms         300ms

Total boot time target: < 3 seconds to Nexus HUD
```

### 3.2 Stage-by-Stage Breakdown

#### Stage 0: BIOS/UEFI (Hardware Init)

```
Duration: 50-200ms
Actions:
  - POST (Power-On Self Test)
  - Initialize RAM
  - Enumerate storage devices
  - Load bootloader from configured source
```

#### Stage 1: iPXE/Bootloader

```
Duration: 100-500ms
Actions:
  - If HTTP Boot: Download kernel.efi from URL
  - If USB: Load kernel.zst from FAT32 partition
  - If Local: Load kernel.zst from C:\CromSpirit
  - Decompress kernel (zstd → ~8MB RAM)
  - Load initramfs.zst
  - Execute kernel with parameters:

    kernel.zst initrd=initramfs.zst \
      root=ram0 \
      rootfstype=ramfs \
      init=/bin/spirit-init \
      crom.mode=auto \
      crom.nodus=discover \
      quiet
```

#### Stage 2: Kernel Initialization

```
Duration: 500ms-1s
Actions:
  - Decompress and mount initramfs
  - Initialize RAM disk
  - Probe hardware (PCI, USB, ACPI)
  - Load essential modules:
    - virtio (for VM communication)
    - zram (memory compression)
    - overlay (filesystem layering)
    - nbd (network block device)
    - vfio-pci (GPU passthrough)
```

#### Stage 3: Spirit-Init (Go Binary)

```
Duration: 300-500ms
Actions:
  1. Mount virtual filesystems
     /proc, /sys, /dev, /run

  2. Setup ZRAM
     - Create /dev/zram0 (50% of RAM)
     - Format with ext4
     - Mount as upper layer for OverlayFS

  3. Network Discovery
     - DHCP for IP configuration
     - Crom-Nodus peer discovery
     - Mount Network Block Device if needed

  4. OverlayFS Assembly
     Lower (Read-Only): SquashFS system image
     Upper (Read-Write): ZRAM or tmpfs
     Work: tmpfs work directory

  5. Pivot Root
     - Switch from initramfs to assembled root

  6. Launch Nexus
```

#### Stage 4: Nexus HUD

```
Duration: 200-300ms
Actions:
  - Initialize Raylib graphics context
  - Load minimal UI theme
  - Display boot splash/status
  - Ready for user interaction
```

---

## 4. Memory Architecture: Tiered Storage

### 4.1 The Three Tiers

```
┌─────────────────────────────────────────────────────────────────┐
│                     MEMORY HIERARCHY                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  TIER 1: HOT (RAM + ZRAM Compressed)                            │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  • Running processes and active files                      │ │
│  │  • LZ4/ZSTD compression: ~3:1 ratio                        │ │
│  │  • Access latency: ~100ns                                  │ │
│  │  • Capacity: 50% of physical RAM                           │ │
│  │  • Volatility: Lost on power off                           │ │
│  └────────────────────────────────────────────────────────────┘ │
│         │                                                        │
│         ▼ (Eviction on memory pressure)                          │
│  TIER 2: WARM (Local Cache - USB/Disk if available)             │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  • Recently used files and system components               │ │
│  │  • bcache or dm-cache for block-level caching              │ │
│  │  • Access latency: ~1-10ms (SSD) / ~10-50ms (HDD)          │ │
│  │  • Capacity: Size of cache partition                       │ │
│  │  • Persistence: Survives reboot (optional)                 │ │
│  └────────────────────────────────────────────────────────────┘ │
│         │                                                        │
│         ▼ (Fetch on cache miss)                                  │
│  TIER 3: COLD (Network - Crom-Nodus / Cloud)                    │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  • Complete system image and user data                     │ │
│  │  • Network Block Device (NBD) or FUSE mount                │ │
│  │  • Access latency: 10-100ms (LAN) / 100-500ms (Internet)   │ │
│  │  • Capacity: Unlimited (distributed)                       │ │
│  │  • Persistence: Permanent (replicated)                     │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 ZRAM Configuration

```bash
#!/bin/bash
# spirit-zram-setup.sh

# Calculate ZRAM size (50% of physical RAM, up to 16GB)
TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
ZRAM_SIZE=$((TOTAL_MEM / 2))
MAX_ZRAM=$((16 * 1024 * 1024))  # 16GB in KB

if [ $ZRAM_SIZE -gt $MAX_ZRAM ]; then
    ZRAM_SIZE=$MAX_ZRAM
fi

# Create and configure ZRAM device
modprobe zram num_devices=1
echo zstd > /sys/block/zram0/comp_algorithm
echo ${ZRAM_SIZE}K > /sys/block/zram0/disksize

# Format and mount
mkfs.ext4 -q /dev/zram0
mkdir -p /mnt/zram
mount /dev/zram0 /mnt/zram
```

### 4.3 OverlayFS Structure

```
mount -t overlay overlay \
    -o lowerdir=/mnt/squashfs,\      # Read-only base system
       upperdir=/mnt/zram/upper,\    # Write layer (RAM)
       workdir=/mnt/zram/work \      # Required work directory
    /mnt/root

# Result:
# /mnt/root
#    ├── bin/      (from squashfs, read-only)
#    ├── etc/      (overlay: reads from squashfs, writes to zram)
#    ├── home/     (overlay: user changes go to zram)
#    ├── usr/      (from squashfs, read-only)
#    └── var/      (overlay: logs/temp go to zram)
```

---

## 5. Boot Configuration Files

### 5.1 iPXE Script (network boot)

```
#!ipxe
# Crom-OS Spirit Network Boot

set spirit-server boot.crom.run
set kernel-url https://${spirit-server}/spirit/kernel.zst
set initrd-url https://${spirit-server}/spirit/initramfs.zst

echo Crom-OS Spirit Network Boot
echo ============================

dhcp
route

echo Downloading kernel...
kernel ${kernel-url} || goto fallback

echo Downloading initramfs...
initrd ${initrd-url} || goto fallback

echo Booting Spirit...
boot || goto fallback

:fallback
echo Boot failed. Entering rescue shell.
shell
```

### 5.2 GRUB Entry (dual-boot with Windows)

```
# /etc/grub.d/40_custom

menuentry "Crom-OS Spirit" {
    insmod part_gpt
    insmod ntfs
    insmod gzio
    insmod zstd

    # Locate Spirit files on Windows partition
    search --file --set=root /CromSpirit/kernel.zst

    echo "Loading Crom-OS Spirit kernel..."
    linux /CromSpirit/kernel.zst \
        root=ram0 \
        init=/bin/spirit-init \
        crom.mode=parasite \
        crom.nodus=auto \
        quiet splash

    echo "Loading initramfs..."
    initrd /CromSpirit/initramfs.zst
}
```

### 5.3 Windows BCD Entry (via bcdedit)

```powershell
# Install Spirit entry in Windows Boot Manager

# Create new boot entry
bcdedit /create /d "Crom-OS Spirit" /application osloader

# Set entry GUID (example, actual GUID will be generated)
$guid = "{12345678-1234-1234-1234-123456789abc}"

# Configure boot parameters
bcdedit /set $guid device partition=C:
bcdedit /set $guid path \CromSpirit\bootx64.efi
bcdedit /set $guid description "Crom-OS Spirit"

# Add to boot menu
bcdedit /displayorder $guid /addlast

# Optional: Set timeout
bcdedit /timeout 5
```

---

## 6. Kernel Modules Strategy

### 6.1 Built-in vs Loadable

```
BUILT-IN (Compiled into kernel):
├── RAM/Memory management
│   ├── zram
│   ├── zswap
│   └── overlay
├── Core filesystem
│   ├── tmpfs
│   ├── squashfs
│   └── ext4
├── Essential network
│   ├── TCP/IP stack
│   └── DHCP client
└── Basic graphics
    ├── EFI framebuffer
    └── DRM core

LOADABLE MODULES (in initramfs):
├── Hardware drivers
│   ├── storage (ahci, nvme, usb-storage)
│   ├── network (e1000e, igb, r8169, iwlwifi)
│   └── graphics (nouveau, amdgpu, i915)
├── Virtualization
│   ├── kvm-intel/kvm-amd
│   ├── vfio-pci
│   └── virtio-*
├── Network storage
│   ├── nbd
│   ├── nfs
│   └── cifs
└── Crom-specific
    └── crom-nodus.ko (kernel module for peer discovery)
```

### 6.2 Module Loading Priority

```
# /etc/modules-load.d/spirit.conf

# Priority 1: Virtualization (load first, claim devices early)
vfio-pci
kvm
kvm_intel
kvm_amd

# Priority 2: Storage (enable disk access)
nvme
ahci
usb_storage

# Priority 3: Network (enable connectivity)
# Loaded dynamically based on hardware detection

# Priority 4: Graphics (last, can be rebound for passthrough)
# Loaded dynamically, can be unloaded for VM passthrough
```

---

## 7. Decision Engine: Boot Mode Selection

```go
// boot-decision.go (pseudo-code)

type BootMode int

const (
    ModeParasite BootMode = iota
    ModeSeed
    ModeHTTPBoot
    ModeNodus
    ModeRescue
)

func DecideBootMode() BootMode {
    // Priority 1: Check for local install
    if fileExists("/mnt/windows/CromSpirit/kernel.zst") {
        log("Found parasite install on Windows")
        return ModeParasite
    }

    // Priority 2: Check for USB boot media
    usbDevices := scanUSBDevices()
    for _, dev := range usbDevices {
        if hasLabel(dev, "CROM_SPIRIT") {
            log("Found Spirit USB seed")
            return ModeSeed
        }
    }

    // Priority 3: Check for network connectivity
    if hasNetwork() {
        // Try HTTP boot endpoint
        if httpReachable("https://boot.crom.run/spirit/manifest.json") {
            log("HTTP Boot endpoint available")
            return ModeHTTPBoot
        }

        // Try Nodus peer discovery
        peers := nodusDiscover(timeout: 5*time.Second)
        if len(peers) > 0 {
            log("Found Nodus peers:", peers)
            return ModeNodus
        }
    }

    // Fallback: No boot source found
    log("No boot source available")
    return ModeRescue
}
```

---

## 8. Build System: Creating the Spirit

### 8.1 Build Dependencies

```bash
# Alpine Linux build host requirements
apk add \
    alpine-sdk \
    linux-headers \
    musl-dev \
    go \
    squashfs-tools \
    zstd \
    mtools \
    dosfstools \
    grub-efi \
    xorriso
```

### 8.2 Build Script

```bash
#!/bin/bash
# build-spirit.sh

set -e

BUILD_DIR="/tmp/spirit-build"
OUTPUT_DIR="/output"

# Clean and prepare
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR/{rootfs,boot,output}

# 1. Build kernel
echo "=== Building Kernel ==="
cd $BUILD_DIR
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.tar.xz
tar xf linux-6.6.tar.xz
cd linux-6.6
cp /configs/spirit-kernel.config .config
make -j$(nproc) bzImage modules
cp arch/x86/boot/bzImage $BUILD_DIR/boot/kernel

# 2. Build rootfs
echo "=== Building Root Filesystem ==="
cd $BUILD_DIR/rootfs
mkdir -p {bin,sbin,etc,lib,usr,var,proc,sys,dev,run,mnt}

# Install Alpine base
apk --root . --initdb add \
    busybox \
    musl \
    openrc \
    eudev

# Copy custom Spirit binaries
cp /built/spirit-init ./sbin/init
cp /built/nexus ./usr/bin/nexus
cp /built/nodus-client ./usr/bin/nodus-client

# Create SquashFS
mksquashfs . $BUILD_DIR/output/rootfs.squashfs \
    -comp zstd \
    -Xcompression-level 19 \
    -all-root

# 3. Build initramfs
echo "=== Building Initramfs ==="
cd $BUILD_DIR
mkdir -p initramfs/{bin,sbin,lib,etc,proc,sys,dev,mnt,run}
# ... (initramfs setup code)
cd initramfs
find . | cpio -o -H newc | zstd -19 > $BUILD_DIR/output/initramfs.zst

# 4. Create final artifacts
echo "=== Creating Boot Artifacts ==="
zstd -19 $BUILD_DIR/boot/kernel -o $BUILD_DIR/output/kernel.zst

# 5. Create ISO
echo "=== Creating ISO ==="
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "CROM_SPIRIT" \
    -eltorito-boot boot/grub/i386-pc/eltorito.img \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    --grub2-boot-info \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -eltorito-catalog boot.catalog \
    -o $OUTPUT_DIR/crom-spirit.iso \
    $BUILD_DIR/output

echo "=== Build Complete ==="
ls -lh $OUTPUT_DIR/
```

---

## 9. Boot Diagnostics

### 9.1 Kernel Command Line Parameters

```
crom.debug=1           # Enable verbose boot messages
crom.mode=<mode>       # Force boot mode (parasite/seed/http/nodus/rescue)
crom.nodus.server=<ip> # Force specific Nodus server
crom.gpu=passthrough   # Mark GPU for VM passthrough
crom.ram.limit=<mb>    # Limit RAM usage (testing)
crom.network.timeout=<s> # Network discovery timeout
```

### 9.2 Boot Failure Recovery

```
┌────────────────────────────────────────────────────────────────┐
│                   RESCUE SHELL COMMANDS                         │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  spirit-diag           # Run full system diagnostics           │
│  spirit-net scan       # Scan for Nodus peers                  │
│  spirit-mount <dev>    # Attempt to mount device               │
│  spirit-fetch <url>    # Download and run from URL             │
│  spirit-usb            # Prepare USB stick as boot media       │
│  dmesg                 # View kernel messages                  │
│  ip addr               # Show network configuration            │
│  lspci                 # List PCI devices                      │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

---

_Document Version: 1.0_  
_Project: Crom-OS Spirit (Project Aether)_  
_Classification: Kernel & Boot Specification_
