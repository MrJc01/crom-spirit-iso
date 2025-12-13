# 🗺️ CROM-OS SPIRIT: Development Roadmap

---

## Overview

The development of Crom-OS Spirit is divided into 4 progressive phases:

```
┌─────────────────────────────────────────────────────────────────┐
│                     DEVELOPMENT PHASES                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  PHASE 1       PHASE 2       PHASE 3       PHASE 4              │
│  GENESIS       NEXUS         BRIDGE        OMNIPRESENCE         │
│  ════════      ═════         ══════        ════════════         │
│                                                                  │
│  Boot Alpine   Integrate     Mount disks   Network boot         │
│  in RAM        Nexus HUD     Connect VMs   GPU passthrough      │
│  Raylib test   Terminal UI   Nodus P2P     AI integration       │
│                                                                  │
│  ▓▓▓▓▓░░░░░   ░░░░░░░░░░    ░░░░░░░░░░    ░░░░░░░░░░           │
│  In Progress   Planned       Planned       Planned               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: GENESIS (Weeks 1-4)

**Goal:** Boot a minimal system entirely in RAM and display a Raylib window.

### Deliverables

| Task | Description                         | Status |
| ---- | ----------------------------------- | ------ |
| 1.1  | Create Alpine Linux base (diskless) | ⬜     |
| 1.2  | Configure ZRAM + OverlayFS          | ⬜     |
| 1.3  | Build custom kernel (minimal)       | ⬜     |
| 1.4  | Create spirit-init (Go binary)      | ⬜     |
| 1.5  | Boot to Raylib "Hello World"        | ⬜     |
| 1.6  | Create build system (Makefile)      | ⬜     |
| 1.7  | Generate bootable ISO               | ⬜     |

### Success Criteria

```
✓ System boots from USB in < 10 seconds
✓ Raylib window displays on screen
✓ No disk mounts (pure RAM)
✓ ISO size < 100MB
```

### Technical Tasks

```bash
# 1. Setup build environment
docker build -t spirit-builder .

# 2. Build minimal kernel
make kernel ARCH=x86_64

# 3. Build spirit-init
CGO_ENABLED=0 go build -o spirit-init ./cmd/init

# 4. Build Raylib test
go build -tags static -o raylib-test ./cmd/raylib-test

# 5. Create ISO
make iso
```

---

## Phase 2: NEXUS INTEGRATION (Weeks 5-8)

**Goal:** Port the crom-nexus interface to run as the primary UI.

### Deliverables

| Task | Description                   | Status |
| ---- | ----------------------------- | ------ |
| 2.1  | Port Nexus codebase to Spirit | ⬜     |
| 2.2  | Implement Bubble mode         | ⬜     |
| 2.3  | Implement Dashboard mode      | ⬜     |
| 2.4  | Implement Terminal Grid       | ⬜     |
| 2.5  | Integrate QuickJS scripting   | ⬜     |
| 2.6  | Add widget system             | ⬜     |
| 2.7  | Create headless browser       | ⬜     |

### Success Criteria

```
✓ Nexus runs as primary interface
✓ Terminal commands work
✓ State transitions are smooth (< 100ms)
✓ Widgets display system info
✓ QuickJS scripts execute
```

### Architecture

```
spirit-init
    │
    └──► Nexus (Raylib)
          ├── Bubble
          ├── Dashboard
          │    ├── CPU Widget
          │    ├── RAM Widget
          │    ├── Network Widget
          │    └── Terminal Widget
          └── Terminal Grid
```

---

## Phase 3: THE BRIDGE (Weeks 9-12)

**Goal:** Connect to external storage and virtualize Windows/Linux.

### Deliverables

| Task | Description                | Status |
| ---- | -------------------------- | ------ |
| 3.1  | Implement Nodus P2P client | ⬜     |
| 3.2  | Create NBD mount system    | ⬜     |
| 3.3  | Read Windows partitions    | ⬜     |
| 3.4  | Integrate KVM/QEMU         | ⬜     |
| 3.5  | Create VM manager          | ⬜     |
| 3.6  | Implement @ command proxy  | ⬜     |
| 3.7  | Add virtio-serial agent    | ⬜     |

### Success Criteria

```
✓ Spirit discovers Nodus peers
✓ Can read files from Windows partition
✓ Windows VM boots within Spirit
✓ @windows command executes in VM
✓ VM state save/restore works
```

### Integration Points

```
Spirit ────► Nodus Network
  │              │
  │              └──► Remote files (NBD)
  │
  ├────► Local Windows partition (NTFS read)
  │
  └────► KVM/QEMU
             │
             └──► Windows VM
                    │
                    └──► spirit-agent.exe
```

---

## Phase 4: OMNIPRESENCE (Weeks 13-16)

**Goal:** Network boot without physical media and single GPU passthrough.

### Deliverables

| Task | Description                | Status |
| ---- | -------------------------- | ------ |
| 4.1  | Implement HTTP Boot server | ⬜     |
| 4.2  | Create iPXE chainloader    | ⬜     |
| 4.3  | Add PXE/DHCP discovery     | ⬜     |
| 4.4  | Implement GPU passthrough  | ⬜     |
| 4.5  | Create passthrough script  | ⬜     |
| 4.6  | Integrate Llama.cpp        | ⬜     |
| 4.7  | Build AI Sentinel          | ⬜     |
| 4.8  | Add voice commands         | ⬜     |

### Success Criteria

```
✓ PC boots from network (no USB)
✓ GPU switches to Windows VM
✓ GPU returns to Spirit without reboot
✓ AI responds to natural language
✓ Sentinel monitors system automatically
```

### GPU Passthrough Flow

```
State 1          State 2          State 3
─────────        ─────────        ─────────
Spirit+GPU  ──►  Spirit(FB)  ──►  Spirit+GPU
                 Windows+GPU

passthrough()    user gaming      return_gpu()
```

---

## Milestones Summary

| Phase        | Duration | Key Deliverable          |
| ------------ | -------- | ------------------------ |
| Genesis      | 4 weeks  | Bootable ISO with Raylib |
| Nexus        | 4 weeks  | Full HUD interface       |
| Bridge       | 4 weeks  | Windows VM integration   |
| Omnipresence | 4 weeks  | Network boot + AI        |

**Total Estimated Time:** 16 weeks (4 months)

---

## Future Phases (Post-1.0)

- **Phase 5: Cloud Integration** - Managed cloud backup
- **Phase 6: Mobile Companion** - Android Nodus app
- **Phase 7: ARM Support** - Raspberry Pi / Mac M-series
- **Phase 8: Secure Boot** - Signed kernel support

---

## Getting Started

```bash
# Clone repository
git clone https://github.com/user/crom-spirit

# Build Phase 1
cd crom-spirit
make genesis

# Test in VM
make test-qemu

# Create ISO
make iso
```

---

_Document Version: 1.0_  
_Project: Crom-OS Spirit (Project Aether)_  
_Classification: Development Roadmap_
