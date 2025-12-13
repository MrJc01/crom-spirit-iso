// Package ui - HUD (Heads-Up Display) overlay
package ui

import (
	"fmt"
	"os"
	"runtime"
	"strings"
	"time"

	rl "github.com/gen2brain/raylib-go/raylib"
)

// HUD displays system status information
type HUD struct {
	ScreenWidth  int32
	ScreenHeight int32

	// Cached values (update periodically)
	memUsed     uint64
	memTotal    uint64
	cpuUsage    float32
	nodusStatus string
	nodusInfo   string
	lastUpdate  time.Time
}

// NewHUD creates a new HUD
func NewHUD(width, height int32) *HUD {
	return &HUD{
		ScreenWidth:  width,
		ScreenHeight: height,
		nodusStatus:  "Checking...",
	}
}

// Update refreshes system stats
func (h *HUD) Update() {
	if time.Since(h.lastUpdate) < time.Second {
		return // Only update once per second
	}
	h.lastUpdate = time.Now()

	// Memory stats
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	h.memUsed = m.Alloc / 1024 / 1024 // MB

	// Try to get total memory from /proc/meminfo
	h.memTotal = h.getTotalMemory()

	// Check Nodus status by looking for socket/process
	h.nodusStatus, h.nodusInfo = h.checkNodusStatus()
}

// getTotalMemory reads from /proc/meminfo
func (h *HUD) getTotalMemory() uint64 {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return 0
	}

	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "MemTotal:") {
			var total uint64
			fmt.Sscanf(line, "MemTotal: %d kB", &total)
			return total / 1024 // Convert to MB
		}
	}
	return 0
}

// checkNodusStatus checks if Nodus daemon is running
func (h *HUD) checkNodusStatus() (string, string) {
	// Check for Nodus socket or process
	if _, err := os.Stat("/run/nodus.sock"); err == nil {
		return "Online", "P2P Active"
	}

	// Check /mnt/nodus mount
	if _, err := os.Stat("/mnt/nodus"); err == nil {
		return "Mounted", "/mnt/nodus"
	}

	return "Offline", "Not running"
}

// Draw renders the HUD
func (h *HUD) Draw() {
	// Top bar background
	rl.DrawRectangle(0, 0, h.ScreenWidth, 40, rl.NewColor(15, 15, 30, 230))
	rl.DrawRectangle(0, 40, h.ScreenWidth, 1, rl.NewColor(80, 80, 120, 150))

	// Left: Title
	rl.DrawText("Crom-OS Spirit", 15, 10, 20, rl.NewColor(200, 200, 255, 255))

	// Right: System info
	memInfo := fmt.Sprintf("RAM: %dMB", h.memUsed)
	if h.memTotal > 0 {
		memInfo = fmt.Sprintf("RAM: %d/%dMB", h.memUsed, h.memTotal)
	}

	nodusColor := rl.NewColor(100, 255, 150, 255)
	if h.nodusStatus == "Offline" {
		nodusColor = rl.NewColor(255, 100, 100, 255)
	}

	infoText := fmt.Sprintf("%s | Nodus: %s", memInfo, h.nodusStatus)
	textWidth := rl.MeasureText(infoText, 16)
	rl.DrawText(infoText, h.ScreenWidth-textWidth-15, 12, 16, nodusColor)

	// Center: Clock
	timeStr := time.Now().Format("15:04")
	timeWidth := rl.MeasureText(timeStr, 18)
	rl.DrawText(timeStr, (h.ScreenWidth-timeWidth)/2, 11, 18, rl.White)
}

// SetNodusStatus manually sets Nodus status (for external updates)
func (h *HUD) SetNodusStatus(status, info string) {
	h.nodusStatus = status
	h.nodusInfo = info
}
