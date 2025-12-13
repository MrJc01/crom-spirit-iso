# 🔮 Crom-OS Spirit

**A Revolutionary Diskless Operating System with P2P Storage and GPU Passthrough**

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)]()
[![License](https://img.shields.io/badge/license-MIT-blue)]()
[![Version](https://img.shields.io/badge/version-1.0.0-purple)]()

---

## 🌟 What is Spirit?

Crom-OS Spirit is a **100% RAM-resident operating system** that breaks free from traditional storage constraints:

- 📀 **No Local Disk Required** - Runs entirely from RAM via USB boot
- 🌐 **P2P Cloud Storage (Nodus)** - Your files exist on the network, not your hardware
- 🖥️ **GPU Passthrough** - Run Windows in a VM with full GPU performance
- 🎨 **Custom UI (Nexus)** - Raylib-powered interface without X11/Wayland

---

## 🚀 Quick Start

### Option 1: Docker Build (Recommended)

```bash
# Clone the repository
git clone https://github.com/MrJc01/crom-spirit-iso
cd crom-spirit-iso

# Build the ISO using Docker
docker build -t spirit-builder .
docker run --rm -v $(pwd)/output:/output spirit-builder

# The ISO will be in ./output/spirit-v1.0.iso
```

### Option 2: Native Linux Build

```bash
# Install dependencies (Ubuntu/Debian)
sudo apt install golang gcc make xorriso syslinux-utils \
    libfuse-dev libvirt-dev

# Build
./scripts/build_iso.sh

# ISO will be in ./build/spirit-v1.0.iso
```

### Option 3: Docker Compose

```bash
# Build ISO
docker-compose run build-iso

# Test in QEMU (VNC on port 5900)
docker-compose up test-qemu
```

---

## 🧪 Testing

### QEMU (Local)

```bash
qemu-system-x86_64 \
    -cdrom build/spirit-v1.0.iso \
    -m 2048 \
    -enable-kvm \
    -cpu host
```

### DistroSea

Upload `spirit-v1.0.iso` to [DistroSea](https://distrosea.com/view/) for browser-based testing.

### Physical Hardware

```bash
# Write to USB drive
sudo dd if=build/spirit-v1.0.iso of=/dev/sdX bs=4M status=progress
```

---

## 📁 Project Structure

```
crom-spirit-iso/
├── cmd/
│   ├── init/           # PID 1 - System init
│   ├── nexus/          # UI layer (Raylib)
│   ├── nodus/          # P2P storage daemon
│   └── hypervisor/     # VM manager (libvirt)
├── internal/
│   ├── ui/             # UI components (orb, menu, hud)
│   ├── input/          # Direct evdev input
│   ├── nodus/          # P2P, FUSE, cache
│   └── hypervisor/     # Libvirt bindings
├── scripts/
│   ├── build_iso.sh    # ISO generator
│   ├── gpu_detach.sh   # GPU passthrough setup
│   └── gpu_attach.sh   # GPU restore
├── docs/               # Full documentation
├── tests/              # QA test protocols
├── reports/            # QA reports
├── Dockerfile          # Multi-stage ISO builder
└── docker-compose.yml  # Development environment
```

---

## ⌨️ Keyboard Shortcuts

| Key     | Action               |
| ------- | -------------------- |
| **F3**  | Toggle debug overlay |
| **F4**  | Open terminal        |
| **F5**  | Launch Windows VM    |
| **F6**  | Show Nodus panel     |
| **ESC** | Exit to shell        |

---

## 🔧 Components

### Nexus (UI)

- Raylib-based framebuffer graphics
- Spirit Orb floating action button
- Radial menu system
- Real-time system monitoring

### Nodus (Storage)

- libp2p P2P network
- FUSE filesystem at `/mnt/nodus`
- LRU RAM cache (256MB)
- Automatic peer discovery (mDNS)

### Hypervisor

- libvirt/QEMU/KVM integration
- VFIO GPU passthrough
- Windows VM with full GPU access
- Hot-swap between Spirit and Windows

---

## 📋 Requirements

### Minimum

- **CPU:** x86_64 with VT-x/AMD-V
- **RAM:** 2GB (4GB+ recommended)
- **Boot:** USB or CD/DVD

### For GPU Passthrough

- **GPU:** 2 GPUs (one for host, one for VM)
- **IOMMU:** Enabled in BIOS
- **Kernel:** VFIO modules

---

## 📚 Documentation

| Document                                                         | Description              |
| ---------------------------------------------------------------- | ------------------------ |
| [Core Manifesto](docs/pt-BR/00-MANIFESTO_CENTRAL.md)             | Philosophy and vision    |
| [Kernel & Boot](docs/pt-BR/01-KERNEL_E_BOOT.md)                  | Boot process details     |
| [Nexus UI](docs/pt-BR/02-SISTEMA_VISUAL_NEXUS.md)                | Interface architecture   |
| [Nodus Protocol](docs/pt-BR/03-PROTOCOLO_ARMAZENAMENTO_NODUS.md) | P2P storage              |
| [Virtualization](docs/pt-BR/04-GERENCIADOR_VIRTUALIZACAO.md)     | GPU passthrough          |
| [AI SysOps](docs/pt-BR/05-IA_SYSOPS.md)                          | AI assistant integration |

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

## 📜 License

MIT License - See [LICENSE](LICENSE) for details.

---

## 🔮 The Spirit Philosophy

> "Your computer is just a window to your data. The data lives everywhere and nowhere."

Spirit reimagines the operating system as a **temporary manifestation** of your digital presence. Boot from any USB, connect to the Nodus network, and your entire computing environment materializes from the cloud.

**No disk. No limits. Pure Spirit.**
