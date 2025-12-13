# 🌌 Crom-OS Spirit Documentation

> _"The body is temporary. The Spirit is eternal."_

Welcome to the technical documentation for **Crom-OS Spirit (Project Aether)** — a revolutionary meta-operating system that runs entirely in RAM, manages hardware and VMs, and connects to a distributed storage network.

---

## 📚 Documentation Index

| #   | Document                                                 | Description                                   |
| --- | -------------------------------------------------------- | --------------------------------------------- |
| 0   | [Core Manifesto](./00-CORE_MANIFESTO.md)                 | Philosophy, three pillars, modes of existence |
| 1   | [Kernel & Boot](./01-KERNEL_AND_BOOT.md)                 | Boot cascade, memory tiers, build system      |
| 2   | [Nexus Visual System](./02-NEXUS_VISUAL_SYSTEM.md)       | HUD interface, states, widgets, scripting     |
| 3   | [Nodus Storage Protocol](./03-NODUS_STORAGE_PROTOCOL.md) | P2P storage, block streaming, encryption      |
| 4   | [Virtualization Manager](./04-VIRTUALIZATION_MANAGER.md) | KVM/QEMU, GPU passthrough, VM commands        |
| 5   | [AI SysOps](./05-AI_SYSOPS.md)                           | Llama.cpp integration, sentinel, NLP          |
| 6   | [Anti-Patterns](./06-ANTI_PATTERNS.md)                   | Constraints, prohibited tech, rules           |
| -   | [Roadmap](./ROADMAP_PHASES.md)                           | 4-phase development plan                      |

---

## 🔑 Key Concepts

### Three Pillars

- **Immortality** — System is read-only in RAM, uncorruptible
- **Omnipresence** — Boot anywhere, data everywhere via network
- **Control** — Manages hardware and orchestrates VMs

### Three Modes

- **Parasita** — Lives inside Windows/Linux as a folder
- **Semente** — Minimal USB boot, streams rest from network
- **Nômade** — Pure network boot, zero physical media

### Technology Stack

- **Kernel:** Alpine Linux (musl, OpenRC)
- **Interface:** Go + Raylib (Nexus HUD)
- **Storage:** Crom-Nodus P2P Protocol
- **Virtualization:** KVM/QEMU with VFIO
- **AI:** Llama.cpp (local LLM)

---

## 🚀 Quick Start

```bash
# Clone and build
git clone https://github.com/user/crom-spirit
cd crom-spirit
make genesis

# Test in QEMU
make test-qemu

# Create bootable ISO
make iso
```

---

## 📋 Project Status

| Phase | Name              | Status         |
| ----- | ----------------- | -------------- |
| 1     | Genesis           | 🔄 In Progress |
| 2     | Nexus Integration | ⬜ Planned     |
| 3     | The Bridge        | ⬜ Planned     |
| 4     | Omnipresence      | ⬜ Planned     |

---

## 🤝 Contributing

See [06-ANTI_PATTERNS.md](./06-ANTI_PATTERNS.md) for development constraints before contributing.

---

_Crom-OS Spirit — Project Aether_
