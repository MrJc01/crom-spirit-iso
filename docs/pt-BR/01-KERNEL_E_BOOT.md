# 🔧 CROM-OS SPIRIT: Kernel e Arquitetura de Boot

---

## 1. Fundação do Kernel

### 1.1 Sistema Base: Alpine Linux Customizado

| Recurso        | Alpine    | Debian             | Arch               |
| -------------- | --------- | ------------------ | ------------------ |
| Tamanho Base   | ~5MB      | ~150MB             | ~200MB             |
| Sistema Init   | OpenRC    | SystemD            | SystemD            |
| Biblioteca C   | musl      | glibc              | glibc              |
| Boot RAM Ready | ✅ Nativo | ❌ Requer trabalho | ❌ Requer trabalho |

> **Por que Alpine?** musl libc produz binários estáticos menores. OpenRC é leve e transparente. A distro foi _projetada_ para containers e operação em RAM.

### 1.2 Configuração do Kernel

```
# Essenciais do Kernel Spirit (.config)

# Operação somente-RAM
CONFIG_TMPFS=y
CONFIG_OVERLAY_FS=y

# Compressão em RAM
CONFIG_ZRAM=y
CONFIG_CRYPTO_LZ4=y
CONFIG_CRYPTO_ZSTD=y

# Virtualização
CONFIG_KVM=y
CONFIG_VFIO=y
CONFIG_VFIO_PCI=y

# Boot por Rede
CONFIG_IP_PNP=y
CONFIG_IP_PNP_DHCP=y
CONFIG_ROOT_NFS=y
```

### 1.3 Sistema Init: Spirit-Init (Binário Go)

```go
// spirit-init.go (conceitual)
func main() {
    // Fase 1: Montar filesystems essenciais
    mountProc(); mountSys(); mountDev()

    // Fase 2: Configurar overlay de memória
    overlay.SetupZRAM("zstd")
    overlay.MountOverlayFS("/", "ram", "cloud")

    // Fase 3: Conectar na rede
    nodus.DiscoverPeers()
    nodus.MountRemoteStorage()

    // Fase 4: Lançar interface
    nexus.Start()
}
```

---

## 2. Processo de Boot: A Cascata

```
┌─────────────────────────────────────────────────────────────────┐
│                        CASCATA DE BOOT                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  TENTATIVA 1: PARASITA LOCAL                                    │
│  Verifica: C:\CromSpirit\kernel.zst existe?                     │
│  Sim → Carrega kernel da partição Windows                       │
│  Não → Continua cascata                                         │
│         │                                                        │
│  TENTATIVA 2: USB SEMENTE                                       │
│  Verifica: Dispositivo USB com label CROM_SPIRIT?               │
│  Sim → Boot do USB, stream restante da rede                     │
│  Não → Continua cascata                                         │
│         │                                                        │
│  TENTATIVA 3: HTTP BOOT (UEFI)                                  │
│  URL: https://boot.crom.run/spirit/kernel.efi                    │
│  Baixa kernel+initramfs direto da nuvem                         │
│         │                                                        │
│  TENTATIVA 4: DESCOBERTA CROM-NODUS                             │
│  Broadcast: "CROM_SPIRIT_SEEK" na UDP 7331                      │
│  Conecta ao peer e faz stream do kernel via NBD                 │
│         │                                                        │
│  FALLBACK: SHELL DE RESGATE                                     │
│  Shell BusyBox mínimo para diagnósticos                         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Cadeia de Boot Detalhada

```
┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐
│ BIOS   │───►│ iPXE   │───►│ Kernel │───►│ Init   │───►│ Nexus  │
│ POST   │    │ Chain  │    │ (RAM)  │    │ (Go)   │    │ (HUD)  │
└────────┘    └────────┘    └────────┘    └────────┘    └────────┘
   50ms          200ms          1s           500ms         300ms

Tempo total de boot alvo: < 3 segundos até o Nexus HUD
```

---

## 4. Arquitetura de Memória: Armazenamento em Camadas

```
┌─────────────────────────────────────────────────────────────────┐
│                     HIERARQUIA DE MEMÓRIA                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  TIER 1: QUENTE (RAM + ZRAM Comprimido)                         │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  • Processos rodando e arquivos ativos                     │ │
│  │  • Compressão LZ4/ZSTD: ~3:1                               │ │
│  │  • Latência: ~100ns                                        │ │
│  │  • Capacidade: 50% da RAM física                           │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  TIER 2: MORNO (Cache Local - USB/Disco se disponível)          │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  • Arquivos recentemente usados                            │ │
│  │  • Latência: ~1-10ms (SSD) / ~10-50ms (HDD)                │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  TIER 3: FRIO (Rede - Crom-Nodus / Nuvem)                       │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  • Imagem completa e dados do usuário                      │ │
│  │  • Latência: 10-100ms (LAN) / 100-500ms (Internet)         │ │
│  │  • Capacidade: Ilimitada (distribuída)                     │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Configuração ZRAM e OverlayFS

### ZRAM

```bash
#!/bin/bash
# spirit-zram-setup.sh

TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
ZRAM_SIZE=$((TOTAL_MEM / 2))

modprobe zram num_devices=1
echo zstd > /sys/block/zram0/comp_algorithm
echo ${ZRAM_SIZE}K > /sys/block/zram0/disksize
mkfs.ext4 -q /dev/zram0
mount /dev/zram0 /mnt/zram
```

### OverlayFS

```bash
mount -t overlay overlay \
    -o lowerdir=/mnt/squashfs,\      # Base somente-leitura
       upperdir=/mnt/zram/upper,\    # Camada de escrita (RAM)
       workdir=/mnt/zram/work \
    /mnt/root
```

---

## 6. Arquivos de Configuração de Boot

### Script iPXE (boot por rede)

```
#!ipxe
# Crom-OS Spirit Network Boot

set spirit-server boot.crom.run
dhcp
kernel https://${spirit-server}/spirit/kernel.zst
initrd https://${spirit-server}/spirit/initramfs.zst
boot
```

### Entrada GRUB (dual-boot)

```
menuentry "Crom-OS Spirit" {
    search --file --set=root /CromSpirit/kernel.zst
    linux /CromSpirit/kernel.zst root=ram0 init=/bin/spirit-init quiet
    initrd /CromSpirit/initramfs.zst
}
```

### Windows BCD (via PowerShell)

```powershell
bcdedit /create /d "Crom-OS Spirit" /application osloader
bcdedit /set {guid} device partition=C:
bcdedit /set {guid} path \CromSpirit\bootx64.efi
bcdedit /displayorder {guid} /addlast
```

---

## 7. Decisão de Modo de Boot

```go
func DecideBootMode() BootMode {
    // Prioridade 1: Instalação local
    if fileExists("/mnt/windows/CromSpirit/kernel.zst") {
        return ModeParasita
    }

    // Prioridade 2: Mídia USB
    if encontraUSB("CROM_SPIRIT") {
        return ModeSemente
    }

    // Prioridade 3: Rede disponível
    if hasNetwork() {
        if httpReachable("boot.crom.run") { return ModeHTTPBoot }
        if nodusDiscover() { return ModeNodus }
    }

    return ModeResgate
}
```

---

## 8. Sistema de Build

```bash
#!/bin/bash
# build-spirit.sh

# 1. Construir kernel
make -C linux-6.6 bzImage modules

# 2. Construir rootfs
mksquashfs rootfs/ rootfs.squashfs -comp zstd

# 3. Criar initramfs
find initramfs/ | cpio -o -H newc | zstd -19 > initramfs.zst

# 4. Criar ISO
xorriso -as mkisofs -o crom-spirit.iso output/
```

---

## 9. Diagnósticos de Boot

### Parâmetros de Linha de Comando

```
crom.debug=1           # Mensagens verbose
crom.mode=<modo>       # Forçar modo (parasita/semente/http/nodus)
crom.nodus.server=<ip> # Servidor Nodus específico
crom.gpu=passthrough   # Marcar GPU para passthrough
```

### Comandos do Shell de Resgate

```
spirit-diag           # Diagnósticos completos
spirit-net scan       # Procurar peers Nodus
spirit-mount <dev>    # Tentar montar dispositivo
dmesg                 # Ver mensagens do kernel
ip addr               # Configuração de rede
```

---

_Versão do Documento: 1.0_  
_Projeto: Crom-OS Spirit (Project Aether)_  
_Classificação: Especificação de Kernel e Boot_
