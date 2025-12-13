package main

import (
	"fmt"
	"math"
	"os"
	"os/exec"
	"syscall"

	"spirit/internal/ui"

	rl "github.com/gen2brain/raylib-go/raylib"
)

// Nexus UI - Spirit's Visual Layer
// Runs directly on Framebuffer (no X11/Wayland)

const (
	WindowTitle = "Crom-OS Spirit - Nexus UI"
)

var (
	screenWidth  int32
	screenHeight int32
)

func main() {
	fmt.Println("🔮 Nexus UI Starting...")

	// Detect screen resolution dynamically
	screenWidth, screenHeight = detectResolution()
	fmt.Printf("📺 Resolution: %dx%d\n", screenWidth, screenHeight)

	// Initialize Raylib
	rl.SetConfigFlags(rl.FlagFullscreenMode | rl.FlagVsyncHint)
	rl.InitWindow(screenWidth, screenHeight, WindowTitle)
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)
	rl.HideCursor()

	// Initialize UI Components
	orb := ui.NewOrb(float32(screenWidth)-100, float32(screenHeight)-100, 40)
	menu := ui.NewRadialMenu(ui.DefaultMenuItems(), 80)
	hud := ui.NewHUD(screenWidth, screenHeight)

	// Command handler
	cmdHandler := NewCommandHandler()

	fmt.Println("✅ Nexus ready")

	for !rl.WindowShouldClose() {
		// --- UPDATE ---
		mousePos := rl.GetMousePosition()
		mouseClick := rl.IsMouseButtonDown(rl.MouseLeftButton)

		// Update components
		if orb.Update(mousePos, mouseClick) {
			menu.Toggle(orb.Position)
		}

		// Check menu command selection
		if cmd := menu.Update(mousePos); cmd != "" {
			fmt.Printf("🎯 Command: %s\n", cmd)
			cmdHandler.Execute(cmd)
		}

		hud.Update()

		// Handle keyboard shortcuts
		handleKeyboard(cmdHandler)

		// --- DRAW ---
		rl.BeginDrawing()
		rl.ClearBackground(rl.NewColor(15, 15, 25, 255))

		// Draw wallpaper/background effect
		drawBackground()

		// Draw components
		hud.Draw()
		menu.Draw()
		orb.Draw()

		// Draw custom cursor
		drawCursor(mousePos)

		// Debug overlay (F3)
		if rl.IsKeyDown(rl.KeyF3) {
			drawDebugOverlay(mousePos)
		}

		rl.EndDrawing()
	}

	fmt.Println("👋 Nexus shutdown")
}

func detectResolution() (int32, int32) {
	monitor := rl.GetCurrentMonitor()
	if monitor >= 0 {
		w := rl.GetMonitorWidth(monitor)
		h := rl.GetMonitorHeight(monitor)
		if w > 0 && h > 0 {
			return int32(w), int32(h)
		}
	}
	return 1920, 1080
}

func drawBackground() {
	// Subtle gradient effect
	for y := int32(0); y < screenHeight; y += 4 {
		alpha := uint8(float32(y) / float32(screenHeight) * 20)
		rl.DrawRectangle(0, y, screenWidth, 4, rl.NewColor(30, 30, 50, alpha))
	}

	// Animated particles (stars)
	t := float32(rl.GetTime())
	for i := 0; i < 50; i++ {
		x := float32(i * 41 % int(screenWidth))
		y := float32(i * 67 % int(screenHeight))
		pulse := float32(math.Sin(float64(t+float32(i)*0.3)))*0.5 + 0.5
		rl.DrawCircle(int32(x), int32(y), 1+pulse, rl.NewColor(100, 100, 150, uint8(50*pulse)))
	}
}

func drawCursor(pos rl.Vector2) {
	// Custom spirit cursor
	rl.DrawCircleV(pos, 8, rl.NewColor(100, 50, 255, 100))
	rl.DrawCircleV(pos, 4, rl.NewColor(150, 100, 255, 200))
	rl.DrawCircleV(pos, 2, rl.White)
}

func drawDebugOverlay(mousePos rl.Vector2) {
	rl.DrawRectangle(5, 45, 220, 100, rl.NewColor(0, 0, 0, 200))
	rl.DrawFPS(10, 50)
	rl.DrawText(fmt.Sprintf("Cursor: %.0f, %.0f", mousePos.X, mousePos.Y), 10, 70, 14, rl.White)
	rl.DrawText(fmt.Sprintf("Res: %dx%d", screenWidth, screenHeight), 10, 90, 14, rl.White)
	rl.DrawText("F3: Debug | F4: Terminal", 10, 110, 12, rl.Gray)
	rl.DrawText("F5: Windows | ESC: Exit", 10, 130, 12, rl.Gray)
}

func handleKeyboard(handler *CommandHandler) {
	if rl.IsKeyPressed(rl.KeyF4) {
		handler.Execute("@terminal")
	}
	if rl.IsKeyPressed(rl.KeyF5) {
		handler.Execute("@windows")
	}
	if rl.IsKeyPressed(rl.KeyF6) {
		handler.Execute("@nodus")
	}
}

// CommandHandler processes menu and keyboard commands
type CommandHandler struct {
	terminalPID int
}

func NewCommandHandler() *CommandHandler {
	return &CommandHandler{}
}

func (h *CommandHandler) Execute(cmd string) {
	switch cmd {
	case "@windows":
		h.launchWindows()
	case "@terminal":
		h.launchTerminal()
	case "@nodus":
		h.showNodusPanel()
	case "@settings":
		h.showSettings()
	default:
		fmt.Printf("❓ Unknown: %s\n", cmd)
	}
}

func (h *CommandHandler) launchWindows() {
	fmt.Println("🖥️  Launching Windows VM...")

	// Check if hypervisor is running
	if _, err := os.Stat("/run/hypervisor.sock"); os.IsNotExist(err) {
		fmt.Println("⚠️  Hypervisor not running")
		return
	}

	// Execute GPU detach and VM start
	go func() {
		// Detach GPU
		exec.Command("/bin/gpu_detach").Run()

		// Start VM via hypervisor
		exec.Command("/bin/hypervisor", "start", "spirit-windows").Run()
	}()
}

func (h *CommandHandler) launchTerminal() {
	fmt.Println("🐚 Opening terminal...")

	// Switch to TTY2 for terminal
	// In real implementation, would overlay a terminal widget
	go func() {
		cmd := exec.Command("/bin/sh")
		cmd.Stdin = os.Stdin
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.SysProcAttr = &syscall.SysProcAttr{Setctty: true, Setsid: true}
		cmd.Run()
	}()
}

func (h *CommandHandler) showNodusPanel() {
	fmt.Println("🌐 Nodus Status Panel")

	// Check Nodus mount
	if _, err := os.Stat("/mnt/nodus"); err == nil {
		entries, _ := os.ReadDir("/mnt/nodus")
		fmt.Printf("   Files in cache: %d\n", len(entries))
	}

	// Check peer count (would read from Nodus socket)
	fmt.Println("   Peers: checking...")
}

func (h *CommandHandler) showSettings() {
	fmt.Println("⚙️  Settings Panel")
	// Future: show settings overlay
}
