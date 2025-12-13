package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"spirit/internal/hypervisor"
)

// Hypervisor Manager - Spirit's VM Orchestration Layer
func main() {
	fmt.Println("🖥️  Spirit Hypervisor Starting...")

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Connect to libvirt
	hv, err := hypervisor.Connect()
	if err != nil {
		fmt.Printf("❌ Failed to connect to libvirt: %v\n", err)
		os.Exit(1)
	}
	defer hv.Close()

	fmt.Printf("✅ Connected to: %s\n", hv.URI())
	fmt.Printf("📊 Host capabilities: %s\n", hv.Capabilities())

	// List existing VMs
	vms, err := hv.ListVMs()
	if err != nil {
		fmt.Printf("⚠️  Failed to list VMs: %v\n", err)
	} else {
		fmt.Printf("📋 Found %d VMs\n", len(vms))
		for _, vm := range vms {
			fmt.Printf("   - %s (%s)\n", vm.Name, vm.State)
		}
	}

	// Wait for commands (in production, this integrates with Nexus)
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	fmt.Println("🚀 Hypervisor ready. Use Nexus '@windows' to boot VM.")
	<-sigChan

	fmt.Println("\n👋 Hypervisor shutting down...")
}
