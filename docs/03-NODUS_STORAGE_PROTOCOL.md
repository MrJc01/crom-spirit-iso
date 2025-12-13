# 📡 CROM-OS SPIRIT: Nodus Storage Protocol

---

## 1. The Core Concept: Diskless Operation

Traditional OS is bound to disk. Delete the disk, OS dies. Spirit decouples storage:

```
TRADITIONAL:  PC ──► DISK ──► OS (Disk dies = Dead)

SPIRIT:       PC ──► NETWORK ──► [Peer1][Peer2][Cloud]
                     (Storage is everywhere, failure-resistant)
```

---

## 2. Crom-Nodus Protocol

| Feature       | Description                                      |
| ------------- | ------------------------------------------------ |
| Block Storage | Files split into 256KB blocks, addressed by hash |
| Discovery     | UDP broadcast + DHT for peer finding             |
| Transport     | TCP for reliable block transfer                  |
| Encryption    | E2E with X25519 + ChaCha20-Poly1305              |
| Redundancy    | Replication factor: 3                            |

### Protocol Stack

```
Layer 5: File System (FUSE/NBD)
Layer 4: Block Management (SHA-256 content-addressed)
Layer 3: Replication & Distribution
Layer 2: Security (X25519 + Ed25519 + ChaCha20)
Layer 1: Transport (UDP discovery, TCP transfer)
```

---

## 3. Block Streaming

Instead of downloading entire files, Nodus streams blocks on demand:

```
Traditional: Download firefox.exe (200MB) → Execute
             Wait: 30 seconds

Nodus:       Fetch manifest (4KB) → Entry blocks (1MB) → Execute
             Background stream remaining 199MB while running
             Wait: 2 seconds
```

### Block Structure

```go
const BlockSize = 256 * 1024 // 256KB

type Block struct {
    Hash    [32]byte  // SHA-256 of content
    Content []byte    // Raw data
    Index   uint64    // Position in file
    Flags   uint8     // Compression, encryption
}

type FileManifest struct {
    ID        [32]byte    // Unique identifier
    Name      string      // Human-readable
    Size      uint64      // Total size
    Blocks    []BlockRef  // Ordered block list
    Owner     [32]byte    // Owner public key
    Signature []byte      // Ed25519 signature
}
```

---

## 4. Peer Discovery

### Discovery Flow

1. **Local**: UDP broadcast on port 7331
2. **Extended**: DHT via bootstrap nodes
3. **Connect**: TCP on port 7332, key exchange

```go
const (
    DiscoveryPort = 7331  // UDP
    TransferPort  = 7332  // TCP
)

type DiscoverMessage struct {
    Magic     [4]byte   // "CROM"
    Version   uint8
    NodeID    [32]byte  // Ed25519 public key
    Timestamp int64
}
```

---

## 5. Distributed Sharding

User data is split, encrypted, and distributed:

```
File: document.pdf (10MB)

Step 1: Chunking → 40 blocks of 256KB
Step 2: Encryption → ChaCha20-Poly1305 per block
Step 3: Distribution → Each block on 3 peers
Step 4: Manifest → Replicated to priority peers + cloud

Result: Can survive loss of any 2 peers
```

### Encryption

```go
func EncryptBlock(plaintext []byte, blockIndex uint64) []byte {
    fileKey := deriveFileKey(masterKey, blockIndex)
    aead, _ := chacha20poly1305.NewX(fileKey[:])
    nonce := randomNonce()
    return aead.Seal(nonce, nonce, plaintext, nil)
}
```

---

## 6. Network Block Device (NBD)

Spirit mounts Nodus as a local disk:

```bash
$ nodus-mount /dev/nbd0 --volume=user-data --cache=2G
$ mount /dev/nbd0 /home
```

```
Linux Kernel
    │
    ▼
/dev/nbd0 (Network Block Device)
    │
    ▼
nodus-nbd (Go daemon)
    │
    ├── Block Cache (LRU)
    │   - Hot: RAM
    │   - Warm: Local disk
    │
    └── Nodus P2P Network
        [Peer1][Peer2][Cloud]
```

---

## 7. Boot from Network

### HTTP Boot + Nodus (6 seconds total)

| Time | Action                                   |
| ---- | ---------------------------------------- |
| T+0s | BIOS downloads bootx64.efi (50KB)        |
| T+1s | EFI downloads kernel.zst + initramfs.zst |
| T+3s | Kernel starts, DHCP, spirit-init         |
| T+4s | Nodus discovers local peers              |
| T+5s | NBD mounts, OverlayFS assembles          |
| T+6s | Nexus HUD ready                          |

### Boot from Phone

Phone running Nodus app caches boot files. PC discovers phone on WiFi, streams kernel and mounts NBD over WiFi. No USB needed!

---

## 8. Security Model

| Threat        | Mitigation                  |
| ------------- | --------------------------- |
| Impersonation | Ed25519 signatures          |
| Tampering     | Content-addressed (SHA-256) |
| Interception  | E2E encryption (ChaCha20)   |
| Replay        | Timestamps + nonces         |
| DoS           | Rate limiting               |

### Trust Hierarchy

1. **Self**: User's identity key (full access)
2. **Trusted Peers**: Explicit add (can store blocks)
3. **Network Peers**: DHT discovered (verify by hash)
4. **Cloud**: Encrypted backup (cannot read data)

---

## 9. Configuration

```yaml
# ~/.config/spirit/nodus.yaml
network:
  listenPort: 7332
  discoveryPort: 7331
  maxConnections: 50

storage:
  cacheDir: /var/cache/nodus
  cacheSize: 2GB
  replicationFactor: 3

cloud:
  enabled: true
  provider: s3
  bucket: crom-backup
```

---

## 10. CLI Commands

```bash
nodus discover       # Find LAN peers
nodus peers          # List connected
nodus mount <vol>    # Mount volume
nodus sync           # Sync to network
nodus backup         # Upload to cloud
nodus identity       # Show identity
```

---

_Document Version: 1.0_  
_Project: Crom-OS Spirit (Project Aether)_  
_Classification: Storage Protocol Specification_
