//go:build linux

// Package main implements the Nexus HUD overlay for Spirit
// Uses raylib-go for graphics rendering
package main

import (
	"fmt"
	"os"
	"os/exec"
	"syscall"
	"unsafe"
)

// UIState represents the current UI mode
type UIState int

const (
	StateBubble    UIState = iota // Minimal floating icon
	StateDashboard                // Full overlay HUD
	StateTerminal                 // Terminal grid mode
)

// NexusApp is the main application
type NexusApp struct {
	state      UIState
	width      int
	height     int
	running    bool
	fbFd       int
	fbData     []byte
	termOutput string
}

// ANSI colors for terminal rendering
var colors = map[string]uint32{
	"black":   0xFF000000,
	"red":     0xFFFF0000,
	"green":   0xFF00FF00,
	"yellow":  0xFFFFFF00,
	"blue":    0xFF0000FF,
	"magenta": 0xFFFF00FF,
	"cyan":    0xFF00FFFF,
	"white":   0xFFFFFFFF,
	"bg":      0xE0202030,
	"accent":  0xFF00AAFF,
}

func main() {
	fmt.Println("🔮 Nexus HUD Starting...")

	app := &NexusApp{
		state:   StateBubble,
		width:   1920,
		height:  1080,
		running: true,
	}

	// Try to initialize framebuffer
	if err := app.initFramebuffer(); err != nil {
		fmt.Printf("⚠️  Framebuffer not available: %v\n", err)
		fmt.Println("Running in text mode...")
		app.runTextMode()
		return
	}
	defer app.closeFramebuffer()

	// Main loop
	app.run()
}

// initFramebuffer opens /dev/fb0 for direct rendering
func (app *NexusApp) initFramebuffer() error {
	fd, err := syscall.Open("/dev/fb0", syscall.O_RDWR, 0)
	if err != nil {
		return err
	}
	app.fbFd = fd

	// Get framebuffer info (simplified - assumes 1920x1080x32bpp)
	size := app.width * app.height * 4
	data, err := syscall.Mmap(fd, 0, size, syscall.PROT_READ|syscall.PROT_WRITE, syscall.MAP_SHARED)
	if err != nil {
		syscall.Close(fd)
		return err
	}
	app.fbData = data

	return nil
}

func (app *NexusApp) closeFramebuffer() {
	if app.fbData != nil {
		syscall.Munmap(app.fbData)
	}
	if app.fbFd > 0 {
		syscall.Close(app.fbFd)
	}
}

// run is the main graphics loop
func (app *NexusApp) run() {
	for app.running {
		// Check keyboard input
		app.handleInput()

		// Render based on state
		switch app.state {
		case StateBubble:
			app.renderBubble()
		case StateDashboard:
			app.renderDashboard()
		case StateTerminal:
			app.renderTerminal()
		}

		// Simple frame limiting
		// time.Sleep(16 * time.Millisecond)
	}
}

// handleInput reads keyboard events
func (app *NexusApp) handleInput() {
	// TODO: Read from /dev/input/eventX
	// For now, this is a placeholder
}

// runTextMode runs a simple text-based version
func (app *NexusApp) runTextMode() {
	fmt.Println("")
	fmt.Println("╔══════════════════════════════════════╗")
	fmt.Println("║       🔮 NEXUS HUD (Text Mode)       ║")
	fmt.Println("╠══════════════════════════════════════╣")
	fmt.Println("║                                      ║")
	fmt.Println("║  [D] Dashboard                       ║")
	fmt.Println("║  [T] Terminal                        ║")
	fmt.Println("║  [Q] Quit                            ║")
	fmt.Println("║                                      ║")
	fmt.Println("╚══════════════════════════════════════╝")
	fmt.Println("")
	fmt.Print("Select: ")

	var input string
	fmt.Scanln(&input)

	switch input {
	case "d", "D":
		app.showDashboardText()
	case "t", "T":
		app.showTerminalText()
	case "q", "Q":
		return
	}
}

func (app *NexusApp) showDashboardText() {
	fmt.Println("")
	fmt.Println("╔══════════════════════════════════════╗")
	fmt.Println("║           SPIRIT DASHBOARD           ║")
	fmt.Println("╠══════════════════════════════════════╣")

	// Get system info
	hostname, _ := os.Hostname()
	fmt.Printf("║  Hostname: %-26s ║\n", hostname)

	// Get memory
	out, _ := exec.Command("free", "-h").Output()
	fmt.Println("║                                      ║")
	fmt.Println("║  Memory:                             ║")
	fmt.Printf("║  %s", string(out)[:min(36, len(out))])
	fmt.Println("║                                      ║")
	fmt.Println("║  [B] Back                            ║")
	fmt.Println("╚══════════════════════════════════════╝")

	var input string
	fmt.Scanln(&input)
}

func (app *NexusApp) showTerminalText() {
	fmt.Println("")
	fmt.Println("╔══════════════════════════════════════╗")
	fmt.Println("║          SPIRIT TERMINAL             ║")
	fmt.Println("╚══════════════════════════════════════╝")
	fmt.Println("")

	// Run shell
	cmd := exec.Command("/bin/sh")
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Run()
}

// Framebuffer rendering functions

func (app *NexusApp) setPixel(x, y int, color uint32) {
	if x < 0 || x >= app.width || y < 0 || y >= app.height {
		return
	}
	offset := (y*app.width + x) * 4
	if offset+4 > len(app.fbData) {
		return
	}
	*(*uint32)(unsafe.Pointer(&app.fbData[offset])) = color
}

func (app *NexusApp) fillRect(x, y, w, h int, color uint32) {
	for dy := 0; dy < h; dy++ {
		for dx := 0; dx < w; dx++ {
			app.setPixel(x+dx, y+dy, color)
		}
	}
}

func (app *NexusApp) renderBubble() {
	// Draw small circle in corner
	cx, cy := app.width-80, app.height-80
	radius := 30
	for dy := -radius; dy <= radius; dy++ {
		for dx := -radius; dx <= radius; dx++ {
			if dx*dx+dy*dy <= radius*radius {
				app.setPixel(cx+dx, cy+dy, colors["accent"])
			}
		}
	}
}

func (app *NexusApp) renderDashboard() {
	// Semi-transparent overlay
	app.fillRect(100, 100, app.width-200, app.height-200, colors["bg"])

	// Border
	for i := 0; i < 3; i++ {
		app.fillRect(100+i, 100, 1, app.height-200, colors["accent"])
		app.fillRect(app.width-100-i, 100, 1, app.height-200, colors["accent"])
		app.fillRect(100, 100+i, app.width-200, 1, colors["accent"])
		app.fillRect(100, app.height-100-i, app.width-200, 1, colors["accent"])
	}
}

func (app *NexusApp) renderTerminal() {
	// Full screen terminal background
	app.fillRect(0, 0, app.width, app.height, 0xFF101020)

	// Draw terminal grid (4 tiles)
	halfW := app.width / 2
	halfH := app.height / 2

	app.fillRect(0, 0, halfW-2, halfH-2, 0xFF151525)
	app.fillRect(halfW+2, 0, halfW-2, halfH-2, 0xFF151525)
	app.fillRect(0, halfH+2, halfW-2, halfH-2, 0xFF151525)
	app.fillRect(halfW+2, halfH+2, halfW-2, halfH-2, 0xFF151525)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
