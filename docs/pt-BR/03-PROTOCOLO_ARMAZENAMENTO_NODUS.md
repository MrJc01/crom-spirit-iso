# 📡 CROM-OS SPIRIT: Protocolo de Armazenamento Nodus

---

## 1. Conceito Central: Operação Sem Disco

SO tradicional está preso ao disco. Deleta o disco, SO morre. O Spirit desacopla:

```
TRADICIONAL:  PC ──► DISCO ──► SO (Disco morre = Morto)

SPIRIT:       PC ──► REDE ──► [Peer1][Peer2][Nuvem]
                     (Armazenamento em todo lugar, resistente a falhas)
```

---

## 2. Protocolo Crom-Nodus

| Recurso                 | Descrição                                                   |
| ----------------------- | ----------------------------------------------------------- |
| Armazenamento de Blocos | Arquivos divididos em blocos de 256KB, endereçados por hash |
| Descoberta              | Broadcast UDP + DHT para encontrar peers                    |
| Transporte              | TCP para transferência confiável                            |
| Criptografia            | E2E com X25519 + ChaCha20-Poly1305                          |
| Redundância             | Fator de replicação: 3                                      |

### Stack do Protocolo

```
Camada 5: Sistema de Arquivos (FUSE/NBD)
Camada 4: Gerenciamento de Blocos (SHA-256 endereçado por conteúdo)
Camada 3: Replicação & Distribuição
Camada 2: Segurança (X25519 + Ed25519 + ChaCha20)
Camada 1: Transporte (UDP descoberta, TCP transferência)
```

---

## 3. Streaming de Blocos

Ao invés de baixar arquivos inteiros, Nodus faz streaming sob demanda:

```
Tradicional: Baixar firefox.exe (200MB) → Executar
             Espera: 30 segundos

Nodus:       Buscar manifesto (4KB) → Blocos de entrada (1MB) → Executar
             Stream em background dos 199MB restantes enquanto roda
             Espera: 2 segundos
```

### Estrutura de Bloco

```go
const BlockSize = 256 * 1024 // 256KB

type Block struct {
    Hash    [32]byte  // SHA-256 do conteúdo
    Content []byte    // Dados brutos
    Index   uint64    // Posição no arquivo
    Flags   uint8     // Compressão, criptografia
}

type FileManifest struct {
    ID        [32]byte    // Identificador único
    Name      string      // Nome legível
    Size      uint64      // Tamanho total
    Blocks    []BlockRef  // Lista ordenada de blocos
    Owner     [32]byte    // Chave pública do dono
    Signature []byte      // Assinatura Ed25519
}
```

---

## 4. Descoberta de Peers

### Fluxo de Descoberta

1. **Local**: Broadcast UDP na porta 7331
2. **Extendido**: DHT via nós bootstrap
3. **Conectar**: TCP na porta 7332, troca de chaves

```go
const (
    DiscoveryPort = 7331  // UDP
    TransferPort  = 7332  // TCP
)

type DiscoverMessage struct {
    Magic     [4]byte   // "CROM"
    Version   uint8
    NodeID    [32]byte  // Chave pública Ed25519
    Timestamp int64
}
```

---

## 5. Sharding Distribuído

Dados do usuário são divididos, criptografados e distribuídos:

```
Arquivo: documento.pdf (10MB)

Passo 1: Chunking → 40 blocos de 256KB
Passo 2: Criptografia → ChaCha20-Poly1305 por bloco
Passo 3: Distribuição → Cada bloco em 3 peers
Passo 4: Manifesto → Replicado para peers prioritários + nuvem

Resultado: Pode sobreviver à perda de qualquer 2 peers
```

### Criptografia

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

Spirit monta Nodus como disco local:

```bash
$ nodus-mount /dev/nbd0 --volume=dados-usuario --cache=2G
$ mount /dev/nbd0 /home
```

```
Kernel Linux
    │
    ▼
/dev/nbd0 (Network Block Device)
    │
    ▼
nodus-nbd (daemon Go)
    │
    ├── Cache de Blocos (LRU)
    │   - Quente: RAM
    │   - Morno: Disco local
    │
    └── Rede P2P Nodus
        [Peer1][Peer2][Nuvem]
```

---

## 7. Boot via Rede

### HTTP Boot + Nodus (6 segundos total)

| Tempo | Ação                                 |
| ----- | ------------------------------------ |
| T+0s  | BIOS baixa bootx64.efi (50KB)        |
| T+1s  | EFI baixa kernel.zst + initramfs.zst |
| T+3s  | Kernel inicia, DHCP, spirit-init     |
| T+4s  | Nodus descobre peers locais          |
| T+5s  | NBD monta, OverlayFS monta           |
| T+6s  | Nexus HUD pronto                     |

### Boot via Celular

Celular rodando app Nodus cacheia arquivos de boot. PC descobre celular no WiFi, faz stream do kernel e monta NBD via WiFi. Sem USB necessário!

---

## 8. Modelo de Segurança

| Ameaça        | Mitigação                         |
| ------------- | --------------------------------- |
| Impersonação  | Assinaturas Ed25519               |
| Adulteração   | Endereçado por conteúdo (SHA-256) |
| Interceptação | Criptografia E2E (ChaCha20)       |
| Replay        | Timestamps + nonces               |
| DoS           | Rate limiting                     |

### Hierarquia de Confiança

1. **Self**: Chave de identidade do usuário (acesso total)
2. **Peers Confiáveis**: Adição explícita (podem armazenar blocos)
3. **Peers de Rede**: Descobertos via DHT (verificar por hash)
4. **Nuvem**: Backup criptografado (não pode ler dados)

---

## 9. Configuração

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

## 10. Comandos CLI

```bash
nodus discover       # Encontrar peers LAN
nodus peers          # Listar conectados
nodus mount <vol>    # Montar volume
nodus sync           # Sincronizar para rede
nodus backup         # Upload para nuvem
nodus identity       # Mostrar identidade
```

---

_Versão do Documento: 1.0_  
_Projeto: Crom-OS Spirit (Project Aether)_  
_Classificação: Especificação de Protocolo de Armazenamento_
