// Package ui - Radial Menu component
package ui

import (
	"math"

	rl "github.com/gen2brain/raylib-go/raylib"
)

// MenuItem represents an item in the radial menu
type MenuItem struct {
	Label   string
	Icon    string // Could be a texture ID later
	Command string
}

// RadialMenu is an animated circular menu
type RadialMenu struct {
	Center     rl.Vector2
	Radius     float32
	Items      []MenuItem
	OpenAmount float32 // 0.0 = closed, 1.0 = fully open
	IsOpen     bool

	HoveredItem int // -1 = none
}

// DefaultMenuItems returns the standard Spirit menu
func DefaultMenuItems() []MenuItem {
	return []MenuItem{
		{Label: "Windows", Command: "@windows"},
		{Label: "Terminal", Command: "@terminal"},
		{Label: "Nodus", Command: "@nodus"},
		{Label: "Settings", Command: "@settings"},
	}
}

// NewRadialMenu creates a radial menu
func NewRadialMenu(items []MenuItem, radius float32) *RadialMenu {
	return &RadialMenu{
		Items:       items,
		Radius:      radius,
		HoveredItem: -1,
	}
}

// Toggle opens or closes the menu
func (m *RadialMenu) Toggle(center rl.Vector2) {
	m.IsOpen = !m.IsOpen
	m.Center = center
}

// Update animates the menu and checks for hover
func (m *RadialMenu) Update(mousePos rl.Vector2) string {
	// Animate open/close
	if m.IsOpen && m.OpenAmount < 1.0 {
		m.OpenAmount += 0.15
		if m.OpenAmount > 1.0 {
			m.OpenAmount = 1.0
		}
	} else if !m.IsOpen && m.OpenAmount > 0 {
		m.OpenAmount -= 0.15
		if m.OpenAmount < 0 {
			m.OpenAmount = 0
		}
	}

	// Check hover only when fully open
	m.HoveredItem = -1
	if m.OpenAmount >= 1.0 {
		for i, item := range m.Items {
			pos := m.getItemPosition(i)
			if rl.Vector2Distance(mousePos, pos) <= 30 {
				m.HoveredItem = i
				if rl.IsMouseButtonPressed(rl.MouseLeftButton) {
					return item.Command
				}
			}
		}
	}
	return ""
}

// Draw renders the radial menu
func (m *RadialMenu) Draw() {
	if m.OpenAmount <= 0 {
		return
	}

	numItems := len(m.Items)
	if numItems == 0 {
		return
	}

	// Draw connecting lines from center
	for i := range m.Items {
		pos := m.getItemPosition(i)
		rl.DrawLineEx(m.Center, pos, 2, rl.NewColor(80, 80, 120, uint8(150*m.OpenAmount)))
	}

	// Draw item bubbles
	for i, item := range m.Items {
		pos := m.getItemPosition(i)

		// Bubble background
		bubbleColor := rl.NewColor(50, 50, 80, uint8(220*m.OpenAmount))
		if i == m.HoveredItem {
			bubbleColor = rl.NewColor(80, 80, 140, uint8(255*m.OpenAmount))
		}
		rl.DrawCircleV(pos, 28, bubbleColor)

		// Label
		textWidth := rl.MeasureText(item.Label, 14)
		rl.DrawText(item.Label, int32(pos.X)-textWidth/2, int32(pos.Y)+35, 14, rl.NewColor(200, 200, 255, uint8(255*m.OpenAmount)))
	}
}

func (m *RadialMenu) getItemPosition(index int) rl.Vector2 {
	numItems := len(m.Items)
	angleStep := (2 * math.Pi) / float64(numItems)
	angle := float64(index)*angleStep - math.Pi/2 // Start from top

	effectiveRadius := m.Radius * m.OpenAmount
	x := m.Center.X + float32(math.Cos(angle))*effectiveRadius
	y := m.Center.Y + float32(math.Sin(angle))*effectiveRadius

	return rl.Vector2{X: x, Y: y}
}
