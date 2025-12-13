// Package hypervisor - VM lifecycle management
package hypervisor

import (
	"fmt"
	"strings"
)

// WindowsVMConfig holds configuration for the Windows VM
type WindowsVMConfig struct {
	Name       string
	Memory     uint // MB
	CPUs       uint
	DiskPath   string // Path to Windows disk image
	ISOPath    string // Optional: Windows installer ISO
	GPUAddress string // PCI address for passthrough (e.g., "0000:01:00.0")
}

// DefaultWindowsConfig returns a sensible default configuration
func DefaultWindowsConfig() WindowsVMConfig {
	return WindowsVMConfig{
		Name:     "spirit-windows",
		Memory:   8192, // 8GB
		CPUs:     4,
		DiskPath: "/var/lib/spirit/windows.qcow2",
	}
}

// CreateWindowsVM creates a new Windows VM definition
func (m *Manager) CreateWindowsVM(cfg WindowsVMConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	xml := generateVMXML(cfg)

	_, err := m.conn.DomainDefineXML(xml)
	if err != nil {
		return fmt.Errorf("failed to define VM: %w", err)
	}

	return nil
}

// StartVM starts a VM by name
func (m *Manager) StartVM(name string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	domain, err := m.conn.LookupDomainByName(name)
	if err != nil {
		return fmt.Errorf("VM not found: %w", err)
	}
	defer domain.Free()

	if err := domain.Create(); err != nil {
		return fmt.Errorf("failed to start VM: %w", err)
	}

	return nil
}

// StopVM gracefully stops a VM
func (m *Manager) StopVM(name string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	domain, err := m.conn.LookupDomainByName(name)
	if err != nil {
		return fmt.Errorf("VM not found: %w", err)
	}
	defer domain.Free()

	// Try graceful shutdown first
	if err := domain.Shutdown(); err != nil {
		// Force destroy if shutdown fails
		return domain.Destroy()
	}

	return nil
}

// GetVMState returns the current state of a VM
func (m *Manager) GetVMState(name string) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	domain, err := m.conn.LookupDomainByName(name)
	if err != nil {
		return "", fmt.Errorf("VM not found: %w", err)
	}
	defer domain.Free()

	state, _, err := domain.GetState()
	if err != nil {
		return "", err
	}

	return stateToString(state), nil
}

// generateVMXML creates libvirt XML for a Windows VM with GPU passthrough
func generateVMXML(cfg WindowsVMConfig) string {
	var hostDevXML string
	if cfg.GPUAddress != "" {
		// Parse PCI address (format: 0000:01:00.0)
		parts := strings.Split(cfg.GPUAddress, ":")
		if len(parts) >= 3 {
			domain := parts[0]
			bus := parts[1]
			slotFunc := strings.Split(parts[2], ".")
			slot := slotFunc[0]
			function := "0"
			if len(slotFunc) > 1 {
				function = slotFunc[1]
			}

			hostDevXML = fmt.Sprintf(`
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <source>
        <address domain='0x%s' bus='0x%s' slot='0x%s' function='0x%s'/>
      </source>
    </hostdev>`, domain, bus, slot, function)
		}
	}

	return fmt.Sprintf(`<domain type='kvm'>
  <name>%s</name>
  <memory unit='MiB'>%d</memory>
  <vcpu placement='static'>%d</vcpu>
  <os>
    <type arch='x86_64' machine='q35'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <hyperv>
      <relaxed state='on'/>
      <vapic state='on'/>
      <spinlocks state='on' retries='8191'/>
    </hyperv>
  </features>
  <cpu mode='host-passthrough' check='none'/>
  <clock offset='localtime'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
    <timer name='hypervclock' present='yes'/>
  </clock>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='%s'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
    </interface>
    <input type='tablet' bus='usb'/>
    <graphics type='spice' autoport='yes'>
      <listen type='address' address='127.0.0.1'/>
    </graphics>
    <video>
      <model type='qxl' ram='65536' vram='65536' vgamem='16384' heads='1' primary='yes'/>
    </video>
    %s
  </devices>
</domain>`, cfg.Name, cfg.Memory, cfg.CPUs, cfg.DiskPath, hostDevXML)
}
