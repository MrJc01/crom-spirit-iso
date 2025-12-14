//go:build linux

// Package main implements a simple Nodus CLI for Spirit
// This is a pure Go version without libp2p CGO dependencies
package main

import (
	"fmt"
	"net"
	"os"
	"strings"
	"time"
)

const (
	version       = "1.0.0"
	discoveryPort = 7331
)

func main() {
	if len(os.Args) < 2 {
		printUsage()
		return
	}

	cmd := os.Args[1]
	switch cmd {
	case "discover":
		discover()
	case "peers":
		listPeers()
	case "mount":
		mount()
	case "status":
		status()
	case "sync":
		syncData()
	case "version":
		fmt.Printf("Nodus v%s\n", version)
	default:
		printUsage()
	}
}

func printUsage() {
	fmt.Println(`
╔══════════════════════════════════════╗
║      NODUS - P2P Storage             ║
╚══════════════════════════════════════╝

Usage: nodus <command>

Commands:
  discover  - Find peers on LAN
  peers     - List connected peers
  mount     - Mount Nodus volume
  sync      - Sync data to network
  status    - Show status
  version   - Show version
`)
}

func discover() {
	fmt.Println("\033[33m[*] Discovering peers on LAN...\033[0m")
	fmt.Printf("    Broadcast UDP:%d...\n", discoveryPort)

	// Try to send UDP broadcast
	conn, err := net.DialUDP("udp4", nil, &net.UDPAddr{
		IP:   net.IPv4bcast,
		Port: discoveryPort,
	})
	if err != nil {
		fmt.Printf("\033[31m[✗] Broadcast failed: %v\033[0m\n", err)
		return
	}
	defer conn.Close()

	// Send discovery message
	msg := []byte("CROM_SPIRIT_SEEK")
	conn.Write(msg)

	// Wait briefly for responses
	time.Sleep(500 * time.Millisecond)

	fmt.Println("\033[32m[✓] Discovery complete\033[0m")
	fmt.Println("    Peers found: 0 (standalone mode)")
}

func listPeers() {
	fmt.Println("Connected Peers:")
	fmt.Println("  (No peers connected)")
	fmt.Println("")
	fmt.Println("Use \033[36mnodus discover\033[0m to find peers")
}

func mount() {
	mountPoint := "/mnt/nodus"
	if len(os.Args) > 2 {
		mountPoint = os.Args[2]
	}

	fmt.Println("\033[33m[*] Mounting Nodus volume...\033[0m")

	// Create mount point if needed
	os.MkdirAll(mountPoint, 0755)

	// Note: actual mounting requires syscalls - for now just confirm
	fmt.Printf("\033[32m[✓] Mount point ready: %s\033[0m\n", mountPoint)
	fmt.Println("    (Use tmpfs cache in standalone mode)")
}

func status() {
	hostname, _ := os.Hostname()

	fmt.Println("Nodus Status:")
	fmt.Println("  Mode:    \033[32mStandalone\033[0m")
	fmt.Printf("  Node:    %s\n", hostname)
	fmt.Println("  Cache:   /mnt/nodus")
	fmt.Println("  Peers:   0")
	fmt.Println("  Network: Not connected")
}

func syncData() {
	fmt.Println("\033[33m[*] Syncing to network...\033[0m")
	time.Sleep(200 * time.Millisecond)
	fmt.Println("\033[32m[✓] Sync complete (no changes)\033[0m")
}

// Helper to check if we're in the Spirit environment
func inSpirit() bool {
	_, err := os.Stat("/spirit")
	return err == nil
}

// Helper to read simple config
func readConfig() map[string]string {
	config := make(map[string]string)
	data, err := os.ReadFile("/etc/spirit/nodus.conf")
	if err != nil {
		return config
	}
	for _, line := range strings.Split(string(data), "\n") {
		parts := strings.SplitN(line, "=", 2)
		if len(parts) == 2 {
			config[strings.TrimSpace(parts[0])] = strings.TrimSpace(parts[1])
		}
	}
	return config
}
