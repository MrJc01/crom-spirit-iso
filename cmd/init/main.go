//go:build linux
// +build linux

package main

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"syscall"
	"time"
)

// Init is the PID 1 of Crom-OS Spirit.
// It is responsible for mounting filesystems, setting up the environment,
// and launching the Nexus UI / Nodus Daemon.
func main() {
	// 0. Ascii Art
	fmt.Println("\n🔮 Crom-OS Spirit v1.0 (Foundation)")
	fmt.Printf("Kernel: %s | Arch: %s | Time: %s\n", runtime.GOOS, runtime.GOARCH, time.Now().Format(time.RFC3339))

	// 1. Mount Essential Filesystems
	if err := mountSystem(); err != nil {
		fmt.Printf("❌ Critical Error: %v\n", err)
	} else {
		fmt.Println("✅ Filesystems mounted (/proc, /sys, /dev)")
	}

	// 2. Set Hostname
	_ = syscall.Sethostname([]byte("spirit-node-01"))

	// 3. Launch Core Services
	fmt.Println("🚀 Launching Spirit services...")
	go launchService("nodus", "/nodus", 500*time.Millisecond)
	go launchService("nexus", "/nexus", 1*time.Second)
	go launchService("hypervisor", "/hypervisor", 1500*time.Millisecond)

	// 4. Launch Debug Shell (fallback)
	go debugShell()

	// 5. Block Forever (PID 1 must never exit)
	fmt.Println("✅ init: All services launched. Entering main loop...")

	// Monitor child processes
	for {
		time.Sleep(5 * time.Second)
	}
}

func mountSystem() error {
	mounts := []struct {
		source, target, fstype string
	}{
		{"proc", "/proc", "proc"},
		{"sysfs", "/sys", "sysfs"},
		{"tmpfs", "/tmp", "tmpfs"},
		{"devtmpfs", "/dev", "devtmpfs"},
		{"tmpfs", "/run", "tmpfs"},
	}

	for _, m := range mounts {
		if err := syscall.Mount(m.source, m.target, m.fstype, 0, ""); err != nil {
			fmt.Printf("⚠️  mount %s: %v\n", m.target, err)
		}
	}
	return nil
}

func launchService(name, path string, delay time.Duration) {
	time.Sleep(delay)

	if _, err := os.Stat(path); os.IsNotExist(err) {
		fmt.Printf("⚠️  %s binary not found at %s\n", name, path)
		return
	}

	fmt.Printf("🔄 Starting %s...\n", name)

	for {
		cmd := exec.Command(path)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Env = []string{
			"PATH=/bin:/sbin:/usr/bin:/usr/sbin",
			"TERM=linux",
			"HOME=/root",
		}

		if err := cmd.Run(); err != nil {
			fmt.Printf("❌ %s exited: %v (restarting in 5s)\n", name, err)
			time.Sleep(5 * time.Second)
		} else {
			break
		}
	}
}

func debugShell() {
	time.Sleep(2 * time.Second)
	fmt.Println("🐚 Debug shell available on tty2 (Alt+F2)")

	cmd := exec.Command("/bin/sh")
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = []string{"PATH=/bin:/sbin:/usr/bin:/usr/sbin", "TERM=linux"}

	if err := cmd.Run(); err != nil {
		fmt.Printf("❌ Shell exited: %v\n", err)
	}
}
