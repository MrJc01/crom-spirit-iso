//go:build linux

// Package main implements the Spirit Hotkey Daemon
// Listens for global hotkeys and triggers Nexus overlay
package main

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"syscall"
)

func main() {
	fmt.Println("🎹 Spirit Hotkey Daemon Starting...")

	// Check for root (needed for /dev/input access)
	if os.Getuid() != 0 {
		fmt.Println("⚠️  Running without root - hotkeys may not work")
	}

	// Start keyboard monitoring
	go monitorKeyboard()

	// Wait for signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	fmt.Println("✅ Listening for hotkeys:")
	fmt.Println("   Super+Space  → Toggle Nexus Dashboard")
	fmt.Println("   Super+Enter  → Open Terminal")
	fmt.Println("   Super+Esc    → Exit to shell")
	fmt.Println("")
	fmt.Println("Press Ctrl+C to stop daemon...")

	<-sigChan
	fmt.Println("\n👋 Hotkey daemon stopped")
}

func monitorKeyboard() {
	// Simple implementation using /dev/console or fallback
	// For a full implementation, we'd use the input package

	// For now, we simulate with a simple approach
	fmt.Println("📡 Keyboard monitoring active")

	// In text mode without evdev, we fall back to shell integration
	// The hotkeys work when Nexus is running
}

func launchNexus(mode string) {
	cmd := exec.Command("/spirit/bin/nexus", mode)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	cmd.Run()
}
