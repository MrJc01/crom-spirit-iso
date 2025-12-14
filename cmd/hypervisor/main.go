//go:build linux

// Package main implements a simple Hypervisor CLI for Spirit
// This is a pure Go version without libvirt CGO dependencies
package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

const version = "1.0.0"

func main() {
	if len(os.Args) < 2 {
		printUsage()
		return
	}

	cmd := os.Args[1]
	switch cmd {
	case "list":
		listVMs()
	case "start":
		if len(os.Args) < 3 {
			fmt.Println("Usage: hypervisor start <vm-name>")
			return
		}
		startVM(os.Args[2])
	case "stop":
		if len(os.Args) < 3 {
			fmt.Println("Usage: hypervisor stop <vm-name>")
			return
		}
		stopVM(os.Args[2])
	case "status":
		status()
	case "version":
		fmt.Printf("Hypervisor v%s\n", version)
	default:
		printUsage()
	}
}

func printUsage() {
	fmt.Println(`
╔══════════════════════════════════════╗
║    HYPERVISOR - VM Manager           ║
╚══════════════════════════════════════╝

Usage: hypervisor <command> [args]

Commands:
  list           - List all VMs
  start <name>   - Start a VM
  stop <name>    - Stop a VM
  status         - Show hypervisor status
  version        - Show version
`)
}

func listVMs() {
	fmt.Println("Virtual Machines:")

	// Try virsh if available
	out, err := exec.Command("virsh", "list", "--all").Output()
	if err != nil {
		fmt.Println("  \033[33m(virsh not available or libvirtd not running)\033[0m")
		fmt.Println("")
		fmt.Println("To create a VM:")
		fmt.Println("  1. Create a disk: qemu-img create -f qcow2 /tmp/vm.qcow2 20G")
		fmt.Println("  2. Start VM: qemu-system-x86_64 -hda /tmp/vm.qcow2 -m 2G")
		return
	}

	fmt.Println(string(out))
}

func startVM(name string) {
	fmt.Printf("\033[33m[*] Starting VM: %s...\033[0m\n", name)

	out, err := exec.Command("virsh", "start", name).CombinedOutput()
	if err != nil {
		fmt.Printf("\033[31m[✗] Failed: %s\033[0m\n", strings.TrimSpace(string(out)))
		return
	}

	fmt.Printf("\033[32m[✓] Started: %s\033[0m\n", name)
}

func stopVM(name string) {
	fmt.Printf("\033[33m[*] Stopping VM: %s...\033[0m\n", name)

	out, err := exec.Command("virsh", "shutdown", name).CombinedOutput()
	if err != nil {
		fmt.Printf("\033[31m[✗] Failed: %s\033[0m\n", strings.TrimSpace(string(out)))
		return
	}

	fmt.Printf("\033[32m[✓] Shutdown signal sent: %s\033[0m\n", name)
}

func status() {
	fmt.Println("Hypervisor Status:")
	fmt.Println("  Backend: QEMU/KVM")

	// Check KVM availability
	if _, err := os.Stat("/dev/kvm"); err == nil {
		fmt.Println("  KVM:     \033[32mAvailable\033[0m")
	} else {
		fmt.Println("  KVM:     \033[31mNot available\033[0m")
	}

	// Check libvirtd
	out, err := exec.Command("virsh", "version", "--daemon").Output()
	if err != nil {
		fmt.Println("  Libvirt: \033[33mNot running\033[0m")
	} else {
		lines := strings.Split(string(out), "\n")
		for _, line := range lines[:min(3, len(lines))] {
			if line != "" {
				fmt.Printf("  %s\n", line)
			}
		}
	}

	// Show QEMU version
	qemuOut, err := exec.Command("qemu-system-x86_64", "--version").Output()
	if err == nil {
		lines := strings.Split(string(qemuOut), "\n")
		if len(lines) > 0 {
			fmt.Printf("  QEMU:    %s\n", lines[0])
		}
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
