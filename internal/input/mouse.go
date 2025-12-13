// Package input - Mouse state management
package input

import (
	"sync"
)

// MouseState tracks the current state of the mouse cursor
type MouseState struct {
	mu sync.RWMutex

	X, Y           float64 // Current position
	DeltaX, DeltaY float64 // Movement since last update

	LeftButton   bool
	RightButton  bool
	MiddleButton bool

	ScreenWidth  float64
	ScreenHeight float64
}

// NewMouseState creates a mouse state manager
func NewMouseState(screenWidth, screenHeight float64) *MouseState {
	return &MouseState{
		X:            screenWidth / 2,
		Y:            screenHeight / 2,
		ScreenWidth:  screenWidth,
		ScreenHeight: screenHeight,
	}
}

// UpdatePosition updates mouse position from relative movement
func (m *MouseState) UpdatePosition(dx, dy float64) {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.DeltaX = dx
	m.DeltaY = dy

	m.X += dx
	m.Y += dy

	// Clamp to screen bounds
	if m.X < 0 {
		m.X = 0
	}
	if m.X > m.ScreenWidth {
		m.X = m.ScreenWidth
	}
	if m.Y < 0 {
		m.Y = 0
	}
	if m.Y > m.ScreenHeight {
		m.Y = m.ScreenHeight
	}
}

// SetButton sets the state of a mouse button
func (m *MouseState) SetButton(button int, pressed bool) {
	m.mu.Lock()
	defer m.mu.Unlock()

	switch button {
	case 0x110: // BTN_LEFT
		m.LeftButton = pressed
	case 0x111: // BTN_RIGHT
		m.RightButton = pressed
	case 0x112: // BTN_MIDDLE
		m.MiddleButton = pressed
	}
}

// GetPosition returns the current mouse position (thread-safe)
func (m *MouseState) GetPosition() (x, y float64) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.X, m.Y
}

// IsLeftPressed returns true if left button is pressed
func (m *MouseState) IsLeftPressed() bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.LeftButton
}
