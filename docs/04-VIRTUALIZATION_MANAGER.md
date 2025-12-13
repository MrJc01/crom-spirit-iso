# ⚙️ CROM-OS SPIRIT: Virtualization Manager

---

## 1. Overview

Spirit acts as a **Type-1 Hybrid Hypervisor** using KVM/QEMU to orchestrate guest operating systems.

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
│          │   VM     │    │   VM     │    │ Containers│ │
│          └──────────┘    └──────────┘    └──────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

## 2. KVM/QEMU Configuration

### Base VM Parameters

```bash
#!/bin/bash
# create-windows-vm.sh

qemu-system-x86_64 \
    -name "Windows-Spirit" \
    -enable-kvm \
    -cpu host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time \
    -smp cores=4,threads=2 \
    -m 8G \
    -machine q35,accel=kvm \
    -bios /usr/share/OVMF/OVMF_CODE.fd \
    -drive file=/vm/windows.qcow2,format=qcow2,if=virtio \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0 \
    -device virtio-serial-pci \
    -chardev socket,path=/tmp/vm-windows.sock,server=on,wait=off,id=spirit \
    -device virtserialport,chardev=spirit,name=spirit.0 \
    -monitor unix:/tmp/qemu-monitor.sock,server,nowait
```

---

## 3. Single GPU Passthrough

### The Hot-Swap Process

```
STATE 1: Spirit using GPU          STATE 2: Windows using GPU
┌──────────────────────┐          ┌──────────────────────┐
│ Spirit + Nexus HUD   │   ──►    │ Spirit (headless)    │
│ GPU: Bound to host   │          │ GPU: Passed to VM    │
│ Display: Active      │          │ Display: VM owns     │
└──────────────────────┘          └──────────────────────┘
```

### GPU Passthrough Script

```bash
#!/bin/bash
# gpu-passthrough.sh

GPU_PCI="0000:01:00.0"
GPU_AUDIO="0000:01:00.1"

passthrough_gpu() {
    echo "Stopping display server..."
    systemctl stop nexus-hud

    echo "Unbinding GPU from host driver..."
    echo "$GPU_PCI" > /sys/bus/pci/devices/$GPU_PCI/driver/unbind
    echo "$GPU_AUDIO" > /sys/bus/pci/devices/$GPU_AUDIO/driver/unbind

    echo "Binding to vfio-pci..."
    echo "vfio-pci" > /sys/bus/pci/devices/$GPU_PCI/driver_override
    echo "vfio-pci" > /sys/bus/pci/devices/$GPU_AUDIO/driver_override
    echo "$GPU_PCI" > /sys/bus/pci/drivers/vfio-pci/bind
    echo "$GPU_AUDIO" > /sys/bus/pci/drivers/vfio-pci/bind

    echo "Starting Windows VM with GPU..."
    qemu-system-x86_64 \
        -device vfio-pci,host=$GPU_PCI,multifunction=on \
        -device vfio-pci,host=$GPU_AUDIO \
        # ... other options
}

return_gpu() {
    echo "Stopping VM..."
    echo "quit" | socat - UNIX:/tmp/qemu-monitor.sock

    echo "Unbinding from vfio-pci..."
    echo "$GPU_PCI" > /sys/bus/pci/drivers/vfio-pci/unbind

    echo "Binding to host driver..."
    echo "" > /sys/bus/pci/devices/$GPU_PCI/driver_override
    echo "$GPU_PCI" > /sys/bus/pci/drivers/nvidia/bind  # or amdgpu

    echo "Restarting display server..."
    systemctl start nexus-hud
}
```

---

## 4. VM State Management

### Freeze/Unfreeze (Pause Windows)

```go
// vm/manager.go

type VMState int

const (
    StateRunning VMState = iota
    StatePaused
    StateStopped
)

func (vm *VM) Pause() error {
    // Send "stop" to QEMU monitor
    return vm.monitor.Send("stop")
}

func (vm *VM) Resume() error {
    // Send "cont" to QEMU monitor
    return vm.monitor.Send("cont")
}

func (vm *VM) SaveState(path string) error {
    // Snapshot RAM to file for instant resume
    return vm.monitor.Send(fmt.Sprintf("savevm %s", path))
}
```

---

## 5. Command Proxy System

### @ Command Syntax

```
@<target> <command> [args...]

Targets:
  @windows    Execute in Windows VM
  @linux      Execute in Linux VM
  @docker     Execute in container
  @spirit     Execute on host (default)
```

### Examples

```bash
# Run Windows commands
@windows dir C:\Users
@windows start notepad.exe
@windows tasklist | findstr chrome

# Control VMs
@windows --pause          # Freeze Windows
@windows --resume         # Unfreeze
@windows --snapshot save  # Save state

# Cross-VM operations
@windows ipconfig > @spirit /tmp/win-ip.txt
```

### Implementation

```go
// command/proxy.go

func ExecuteInVM(vmName, command string) (string, error) {
    vm := vmManager.Get(vmName)
    if vm == nil {
        return "", fmt.Errorf("VM %s not found", vmName)
    }

    // Send via virtio-serial
    conn, _ := net.Dial("unix", vm.SocketPath)
    defer conn.Close()

    // Protocol: length-prefixed command
    msg := CommandMessage{
        Type:    "exec",
        Command: command,
    }
    json.NewEncoder(conn).Encode(msg)

    // Read response
    var resp CommandResponse
    json.NewDecoder(conn).Decode(&resp)

    return resp.Output, resp.Error
}
```

---

## 6. VM Communication (virtio-serial)

### Guest Agent (runs inside VM)

```go
// spirit-agent.go (runs in Windows/Linux VM)

func main() {
    // Connect to virtio-serial port
    port, _ := os.OpenFile("/dev/virtio-ports/spirit.0", os.O_RDWR, 0)

    for {
        var cmd CommandMessage
        json.NewDecoder(port).Decode(&cmd)

        switch cmd.Type {
        case "exec":
            output, err := exec.Command("cmd", "/c", cmd.Command).Output()
            resp := CommandResponse{Output: string(output)}
            if err != nil {
                resp.Error = err.Error()
            }
            json.NewEncoder(port).Encode(resp)
        }
    }
}
```

---

## 7. Performance Optimizations

| Optimization      | Description             |
| ----------------- | ----------------------- |
| Huge Pages        | 2MB pages for VM memory |
| CPU Pinning       | Dedicated cores for VM  |
| virtio            | Paravirtualized I/O     |
| IOMMU             | Direct device access    |
| Memory Ballooning | Dynamic RAM allocation  |

```bash
# Huge pages setup
echo 4096 > /proc/sys/vm/nr_hugepages
mount -t hugetlbfs hugetlbfs /dev/hugepages

# CPU pinning (cores 4-7 for Windows VM)
taskset -c 4-7 qemu-system-x86_64 ...
```

---

## 8. Quick Reference

```bash
# VM Management
spirit vm list              # List all VMs
spirit vm start windows     # Start Windows VM
spirit vm stop windows      # Stop VM
spirit vm pause windows     # Freeze VM (RAM)
spirit vm resume windows    # Unfreeze VM

# GPU Passthrough
spirit gpu status           # Show GPU binding
spirit gpu passthrough      # Give GPU to VM
spirit gpu reclaim          # Take GPU back

# Cross-VM commands
@windows cmd /c dir         # Run in Windows
@linux ls -la               # Run in Linux
```

---

_Document Version: 1.0_  
_Project: Crom-OS Spirit (Project Aether)_  
_Classification: Virtualization Specification_
