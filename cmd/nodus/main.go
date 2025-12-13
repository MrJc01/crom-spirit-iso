package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"spirit/internal/nodus"
)

// Nodus Daemon - Spirit's Distributed Storage Layer
func main() {
	fmt.Println("🌐 Nodus Daemon Starting...")

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Initialize the P2P node
	node, err := nodus.NewNode(ctx)
	if err != nil {
		fmt.Printf("❌ Failed to create node: %v\n", err)
		os.Exit(1)
	}
	defer node.Close()

	fmt.Printf("✅ Node ID: %s\n", node.ID())
	fmt.Printf("📡 Listening on: %v\n", node.Addrs())

	// Start peer discovery
	go node.StartDiscovery(ctx)

	// Mount FUSE filesystem
	mountPoint := "/mnt/nodus"
	if len(os.Args) > 1 {
		mountPoint = os.Args[1]
	}

	fs, err := nodus.MountFUSE(mountPoint, node)
	if err != nil {
		fmt.Printf("⚠️  FUSE mount failed: %v (continuing without mount)\n", err)
	} else {
		defer fs.Unmount()
		fmt.Printf("📁 FUSE mounted at: %s\n", mountPoint)
	}

	// Wait for shutdown signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	fmt.Println("🚀 Nodus ready. Press Ctrl+C to stop.")
	<-sigChan

	fmt.Println("\n👋 Nodus shutting down...")
}
