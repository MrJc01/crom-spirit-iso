// Package ui - Spirit Orb (floating action button)
package ui

import (
	"math"

	rl "github.com/gen2brain/raylib-go/raylib"
)

// Orb represents the Spirit Orb floating button
type Orb struct {
	Position rl.Vector2
	Radius   float32
	Hover    bool
	Pressed  bool

	// Animation state
	pulsePhase    float32
	glowIntensity float32
}

// NewOrb creates a new Spirit Orb
func NewOrb(x, y, radius float32) *Orb {
	return &Orb{
		Position:      rl.Vector2{X: x, Y: y},
		Radius:        radius,
		glowIntensity: 0.3,
	}
}

// Update handles orb state based on mouse position
func (o *Orb) Update(mousePos rl.Vector2, mouseClick bool) bool {
	dist := rl.Vector2Distance(mousePos, o.Position)
	o.Hover = dist <= o.Radius

	wasPressed := o.Pressed
	o.Pressed = o.Hover && mouseClick

	// Update animations
	o.pulsePhase += 0.05
	if o.Hover {
		o.glowIntensity = float32(math.Min(float64(o.glowIntensity+0.1), 1.0))
	} else {
		o.glowIntensity = float32(math.Max(float64(o.glowIntensity-0.05), 0.3))
	}

	// Return true if clicked (press->release)
	return wasPressed && !o.Pressed && o.Hover
}

// Draw renders the orb
func (o *Orb) Draw() {
	// Animated outer glow
	pulse := float32(math.Sin(float64(o.pulsePhase))) * 5
	glowAlpha := uint8(100 * o.glowIntensity)
	rl.DrawCircleV(o.Position, o.Radius+15+pulse, rl.NewColor(100, 50, 255, glowAlpha))
	rl.DrawCircleV(o.Position, o.Radius+8, rl.NewColor(80, 40, 200, uint8(150*o.glowIntensity)))

	// Core
	coreColor := rl.NewColor(80, 40, 200, 255)
	if o.Hover {
		coreColor = rl.NewColor(120, 80, 255, 255)
	}
	rl.DrawCircleV(o.Position, o.Radius, coreColor)

	// Inner highlight
	highlight := rl.Vector2{X: o.Position.X - o.Radius*0.3, Y: o.Position.Y - o.Radius*0.3}
	rl.DrawCircleV(highlight, o.Radius*0.25, rl.NewColor(255, 255, 255, 120))
}
