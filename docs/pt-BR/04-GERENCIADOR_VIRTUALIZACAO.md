# ⚙️ CROM-OS SPIRIT: Gerenciador de Virtualização

---

## 1. Visão Geral

O Spirit atua como **Hypervisor Híbrido Type-1** usando KVM/QEMU para orquestrar sistemas operacionais guest.

```
┌─────────────────────────────────────────────────────────┐
│                      HARDWARE                            │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────┐   │
│  │          CROM-OS SPIRIT (Host/Hypervisor)       │   │
│  │  ┌─────────────┐  ┌─────────────────────────┐  │   │
│  │  │  NEXUS HUD  │  │      KVM/QEMU           │  │   │
│  │  └─────────────┘  └───────────┬─────────────┘  │   │
│  └───────────────────────────────┼─────────────────┘   │
│                 ┌────────────────┼────────────────┐    │
│                 ▼                ▼                ▼    │
│          ┌──────────┐    ┌──────────┐    ┌──────────┐ │
│          │ Windows  │    │  Linux   │    │ Docker   │ │
│          │   VM     │    │   VM     │    │Containers│ │
│          └──────────┘    └──────────┘    └──────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Configuração KVM/QEMU

### Parâmetros Base da VM

```bash
#!/bin/bash
# create-windows-vm.sh

qemu-system-x86_64 \
    -name "Windows-Spirit" \
    -enable-kvm \
    -cpu host,hv_relaxed,hv_spinlocks=0x1fff \
    -smp cores=4,threads=2 \
    -m 8G \
    -machine q35,accel=kvm \
    -drive file=/vm/windows.qcow2,format=qcow2,if=virtio \
    -device virtio-serial-pci \
    -chardev socket,path=/tmp/vm-windows.sock,server=on,id=spirit \
    -device virtserialport,chardev=spirit,name=spirit.0
```

---

## 3. GPU Passthrough Única

### Processo de Hot-Swap

```
ESTADO 1: Spirit usando GPU     ESTADO 2: Windows usando GPU
┌──────────────────────┐        ┌──────────────────────┐
│ Spirit + Nexus HUD   │  ──►   │ Spirit (headless)    │
│ GPU: Vinculada host  │        │ GPU: Passada para VM │
│ Display: Ativo       │        │ Display: VM controla │
└──────────────────────┘        └──────────────────────┘
```

### Script de GPU Passthrough

```bash
#!/bin/bash
# gpu-passthrough.sh

GPU_PCI="0000:01:00.0"
GPU_AUDIO="0000:01:00.1"

passthrough_gpu() {
    echo "Parando servidor de display..."
    systemctl stop nexus-hud

    echo "Desvinculando GPU do driver do host..."
    echo "$GPU_PCI" > /sys/bus/pci/devices/$GPU_PCI/driver/unbind

    echo "Vinculando ao vfio-pci..."
    echo "vfio-pci" > /sys/bus/pci/devices/$GPU_PCI/driver_override
    echo "$GPU_PCI" > /sys/bus/pci/drivers/vfio-pci/bind

    echo "Iniciando VM Windows com GPU..."
    qemu-system-x86_64 \
        -device vfio-pci,host=$GPU_PCI \
        # ... outras opções
}

return_gpu() {
    echo "Parando VM..."
    echo "quit" | socat - UNIX:/tmp/qemu-monitor.sock

    echo "Desvinculando do vfio-pci..."
    echo "$GPU_PCI" > /sys/bus/pci/drivers/vfio-pci/unbind

    echo "Vinculando ao driver do host..."
    echo "" > /sys/bus/pci/devices/$GPU_PCI/driver_override
    echo "$GPU_PCI" > /sys/bus/pci/drivers/nvidia/bind

    echo "Reiniciando servidor de display..."
    systemctl start nexus-hud
}
```

---

## 4. Gerenciamento de Estado da VM

### Congelar/Descongelar (Pausar Windows)

```go
// vm/manager.go

func (vm *VM) Pause() error {
    // Envia "stop" para monitor QEMU
    return vm.monitor.Send("stop")
}

func (vm *VM) Resume() error {
    // Envia "cont" para monitor QEMU
    return vm.monitor.Send("cont")
}

func (vm *VM) SaveState(path string) error {
    // Snapshot RAM para arquivo para resume instantâneo
    return vm.monitor.Send(fmt.Sprintf("savevm %s", path))
}
```

---

## 5. Sistema de Comando Proxy

### Sintaxe de Comando @

```
@<alvo> <comando> [args...]

Alvos:
  @windows    Executar na VM Windows
  @linux      Executar na VM Linux
  @docker     Executar em container
  @spirit     Executar no host (padrão)
```

### Exemplos

```bash
# Rodar comandos Windows
@windows dir C:\Users
@windows start notepad.exe
@windows tasklist | findstr chrome

# Controlar VMs
@windows --pause          # Congelar Windows
@windows --resume         # Descongelar
@windows --snapshot save  # Salvar estado

# Operações cross-VM
@windows ipconfig > @spirit /tmp/win-ip.txt
```

---

## 6. Comunicação VM (virtio-serial)

### Agente Guest (roda dentro da VM)

```go
// spirit-agent.go (roda na VM Windows/Linux)

func main() {
    // Conecta na porta virtio-serial
    port, _ := os.OpenFile("/dev/virtio-ports/spirit.0", os.O_RDWR, 0)

    for {
        var cmd CommandMessage
        json.NewDecoder(port).Decode(&cmd)

        switch cmd.Type {
        case "exec":
            output, err := exec.Command("cmd", "/c", cmd.Command).Output()
            resp := CommandResponse{Output: string(output)}
            json.NewEncoder(port).Encode(resp)
        }
    }
}
```

---

## 7. Otimizações de Performance

| Otimização        | Descrição                         |
| ----------------- | --------------------------------- |
| Huge Pages        | Páginas de 2MB para memória da VM |
| CPU Pinning       | Cores dedicados para VM           |
| virtio            | I/O paravirtualizado              |
| IOMMU             | Acesso direto a dispositivo       |
| Memory Ballooning | Alocação dinâmica de RAM          |

```bash
# Setup de huge pages
echo 4096 > /proc/sys/vm/nr_hugepages
mount -t hugetlbfs hugetlbfs /dev/hugepages

# CPU pinning (cores 4-7 para VM Windows)
taskset -c 4-7 qemu-system-x86_64 ...
```

---

## 8. Referência Rápida

```bash
# Gerenciamento de VMs
spirit vm list              # Listar todas VMs
spirit vm start windows     # Iniciar VM Windows
spirit vm stop windows      # Parar VM
spirit vm pause windows     # Congelar VM (RAM)
spirit vm resume windows    # Descongelar VM

# GPU Passthrough
spirit gpu status           # Mostrar binding da GPU
spirit gpu passthrough      # Dar GPU para VM
spirit gpu reclaim          # Pegar GPU de volta

# Comandos cross-VM
@windows cmd /c dir         # Rodar no Windows
@linux ls -la               # Rodar no Linux
```

---

_Versão do Documento: 1.0_  
_Projeto: Crom-OS Spirit (Project Aether)_  
_Classificação: Especificação de Virtualização_
