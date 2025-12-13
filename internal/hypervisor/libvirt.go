// Package hypervisor provides libvirt bindings for VM management
package hypervisor

import (
	"fmt"
	"sync"

	"libvirt.org/go/libvirt"
)

// Manager handles libvirt connections and VM operations
type Manager struct {
	conn *libvirt.Connect
	mu   sync.Mutex
	uri  string
}

// Connect establishes a connection to libvirt (local QEMU/KVM)
func Connect() (*Manager, error) {
	// Try system connection first, then session
	uris := []string{
		"qemu:///system",
		"qemu:///session",
	}

	var conn *libvirt.Connect
	var err error
	var usedURI string

	for _, uri := range uris {
		conn, err = libvirt.NewConnect(uri)
		if err == nil {
			usedURI = uri
			break
		}
	}

	if conn == nil {
		return nil, fmt.Errorf("failed to connect to libvirt: %w", err)
	}

	return &Manager{conn: conn, uri: usedURI}, nil
}

// URI returns the connected libvirt URI
func (m *Manager) URI() string {
	return m.uri
}

// Capabilities returns host virtualization capabilities
func (m *Manager) Capabilities() string {
	caps, err := m.conn.GetCapabilities()
	if err != nil {
		return "unknown"
	}
	// Return just a summary (full XML is very long)
	if len(caps) > 100 {
		return caps[:100] + "..."
	}
	return caps
}

// Close closes the libvirt connection
func (m *Manager) Close() error {
	if m.conn != nil {
		_, err := m.conn.Close()
		return err
	}
	return nil
}

// VMInfo represents basic VM information
type VMInfo struct {
	Name  string
	UUID  string
	State string
}

// ListVMs returns all defined VMs
func (m *Manager) ListVMs() ([]VMInfo, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	domains, err := m.conn.ListAllDomains(libvirt.CONNECT_LIST_DOMAINS_ACTIVE | libvirt.CONNECT_LIST_DOMAINS_INACTIVE)
	if err != nil {
		return nil, err
	}

	var vms []VMInfo
	for _, domain := range domains {
		name, _ := domain.GetName()
		uuid, _ := domain.GetUUIDString()
		state, _, _ := domain.GetState()

		vms = append(vms, VMInfo{
			Name:  name,
			UUID:  uuid,
			State: stateToString(state),
		})
		domain.Free()
	}

	return vms, nil
}

func stateToString(state libvirt.DomainState) string {
	switch state {
	case libvirt.DOMAIN_RUNNING:
		return "running"
	case libvirt.DOMAIN_PAUSED:
		return "paused"
	case libvirt.DOMAIN_SHUTDOWN:
		return "shutdown"
	case libvirt.DOMAIN_SHUTOFF:
		return "off"
	case libvirt.DOMAIN_CRASHED:
		return "crashed"
	default:
		return "unknown"
	}
}
