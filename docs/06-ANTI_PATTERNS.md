# 🚫 CROM-OS SPIRIT: Anti-Patterns & Constraints

---

## 1. The Golden Rule

> **"Everything must be a static binary. The system must survive if you delete every .so file."**

Spirit must run with **zero runtime dependencies** on shared libraries.

---

## 2. Prohibited Technologies

| Technology           | Reason                     | Alternative          |
| -------------------- | -------------------------- | -------------------- |
| **Electron**         | 300MB+ RAM, Chromium bloat | Go + Raylib          |
| **Node.js** (core)   | Dynamic runtime, heavy     | Go (static)          |
| **SystemD**          | Complex, disk-dependent    | OpenRC / custom init |
| **Python** (runtime) | Interpreter, slow startup  | Go (compiled)        |
| **glibc**            | Large, complex             | musl libc            |
| **X11/Wayland**      | Heavy display servers      | DRM/KMS direct       |
| **Docker** (core)    | Requires daemon            | Podman or containerd |
| **WebViews**         | Chrome/Webkit overhead     | Native Raylib UI     |

---

## 3. Forbidden Patterns

### ❌ Disk Assumptions

```go
// WRONG: Assumes disk exists
config, _ := os.ReadFile("/etc/spirit/config.yaml")

// CORRECT: Fallback to network/embedded
config, err := loadConfig()
if err != nil {
    config = embeddedDefaultConfig
}
```

### ❌ Fixed Paths

```go
// WRONG: Hardcoded path
db := openDB("/var/lib/spirit/data.db")

// CORRECT: Memory-first, optional persistence
db := openDB(":memory:")
if hasPersistentStorage() {
    db.Sync(getPersistentPath())
}
```

### ❌ Internet Requirement

```go
// WRONG: Fails without internet
user := fetchFromCloud()

// CORRECT: Offline-first
user, err := localCache.Get("user")
if err != nil && hasNetwork() {
    user = fetchFromCloud()
    localCache.Set("user", user)
}
```

---

## 4. Core Constraints

### C1: Binary Size

- Nexus HUD: < 15MB
- Spirit-init: < 5MB
- Total system: < 100MB

### C2: Boot Time

- Kernel to Nexus: < 3 seconds
- Cold boot to usable: < 10 seconds

### C3: RAM Usage

- Idle system: < 100MB
- With one VM paused: < 200MB

### C4: Disk Usage

- System image: < 500MB
- Minimum to boot: 0 bytes (network boot)

---

## 5. Dependency Rules

### Allowed Dependencies

```
✅ musl libc (static link)
✅ OpenGL/Vulkan (driver)
✅ Linux kernel (required)
✅ Go stdlib (compiled in)
✅ Raylib (static link)
```

### Forbidden Dependencies

```
❌ glibc
❌ libstdc++
❌ Python runtime
❌ Node.js runtime
❌ Java/JVM
❌ .NET runtime
❌ Electron/Chromium
```

---

## 6. Backup Requirements

### Automatic Sync

```yaml
# Backup policy
backup:
  interval: 5m # Sync every 5 minutes
  targets:
    - nodus # P2P network (primary)
    - cloud # Cloud storage (secondary)
  encrypted: true # Always encrypted

  # What to backup
  include:
    - /home # User data
    - /etc/spirit # Configuration

  # What NOT to backup
  exclude:
    - /tmp
    - /var/cache
    - "*.log"
```

### Data Loss Prevention

```
On modified file:
  → Hash block
  → Encrypt block
  → Queue for Nodus sync
  → Confirm replication (3 peers)
  → Mark as safe

Power loss before sync:
  → On next boot, recover from Nodus
  → Max data loss: 5 minutes of work
```

---

## 7. Offline Survival Mode

The system **must work** without any network:

```
┌─────────────────────────────────────────────────────────────┐
│               OFFLINE SURVIVAL MODE                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Network available:                                          │
│  ✓ Full Nodus P2P storage                                   │
│  ✓ Cloud sync                                                │
│  ✓ Remote boot                                               │
│  ✓ AI cloud features                                         │
│                                                              │
│  Network unavailable:                                        │
│  ✓ Boot from local cache/USB                                 │
│  ✓ Access cached files                                       │
│  ✓ Local AI (Llama.cpp)                                     │
│  ✓ VMs still run                                             │
│  ✓ Queue changes for later sync                              │
│  ✗ No new remote files                                       │
│                                                              │
│  Graceful degradation, never crash                          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 8. Security Constraints

| Rule                    | Rationale             |
| ----------------------- | --------------------- |
| No telemetry            | Privacy by default    |
| No cloud keys in binary | Secrets from user     |
| E2E encryption only     | Zero-knowledge design |
| Verify all blocks       | No trust in network   |
| Sign all manifests      | Integrity guarantee   |

---

## 9. Checklist for Contributors

Before submitting code:

- [ ] Does it compile statically? (`go build -ldflags '-extldflags "-static"'`)
- [ ] Does it run without disk? (Test with tmpfs root)
- [ ] Does it work offline? (Test with no network)
- [ ] Is RAM usage acceptable? (Profile with `pprof`)
- [ ] Binary size < limit?
- [ ] No prohibited dependencies?
- [ ] Data backed up before write?

---

_Document Version: 1.0_  
_Project: Crom-OS Spirit (Project Aether)_  
_Classification: Development Constraints_
