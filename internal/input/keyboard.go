//go:build linux

// Package input handles keyboard events from /dev/input
package input

import (
	"encoding/binary"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"syscall"
)

// Key codes (from linux/input-event-codes.h)
const (
	KEY_ESC       = 1
	KEY_ENTER     = 28
	KEY_LEFTCTRL  = 29
	KEY_LEFTSHIFT = 42
	KEY_LEFTALT   = 56
	KEY_SPACE     = 57
	KEY_F1        = 59
	KEY_F2        = 60
	KEY_F3        = 61
	KEY_F4        = 62
	KEY_LEFTMETA  = 125 // Super/Windows key
)

// Event types
const (
	EV_KEY = 1
)

// InputEvent represents a Linux input event
type InputEvent struct {
	Time  syscall.Timeval
	Type  uint16
	Code  uint16
	Value int32
}

// KeyboardHandler captures keyboard input
type KeyboardHandler struct {
	fd          int
	modifiers   uint32
	eventChan   chan KeyEvent
	stopChan    chan struct{}
}

// KeyEvent represents a processed key event
type KeyEvent struct {
	Key       uint16
	Pressed   bool
	Modifiers uint32
}

// Modifier flags
const (
	MOD_CTRL  = 1 << 0
	MOD_SHIFT = 1 << 1
	MOD_ALT   = 1 << 2
	MOD_SUPER = 1 << 3
)

// NewKeyboardHandler creates a new keyboard handler
func NewKeyboardHandler() (*KeyboardHandler, error) {
	// Find keyboard device
	devices, _ := filepath.Glob("/dev/input/event*")
	
	var kbdFd int
	var found bool
	
	for _, dev := range devices {
		fd, err := syscall.Open(dev, syscall.O_RDONLY|syscall.O_NONBLOCK, 0)
		if err != nil {
			continue
		}
		
		// Check if this is a keyboard (simplified check)
		name := make([]byte, 256)
		// EVIOCGNAME ioctl to get device name
		_, _, errno := syscall.Syscall(
			syscall.SYS_IOCTL,
			uintptr(fd),
			uintptr(0x80ff4506), // EVIOCGNAME(256)
			uintptr(unsafe.Pointer(&name[0])),
		)
		if errno == 0 {
			nameStr := strings.ToLower(string(name))
			if strings.Contains(nameStr, "keyboard") || strings.Contains(nameStr, "kbd") {
				kbdFd = fd
				found = true
				fmt.Printf("Found keyboard: %s\n", dev)
				break
			}
		}
		syscall.Close(fd)
	}
	
	if !found {
		return nil, fmt.Errorf("no keyboard found")
	}
	
	return &KeyboardHandler{
		fd:        kbdFd,
		eventChan: make(chan KeyEvent, 10),
		stopChan:  make(chan struct{}),
	}, nil
}

// Start begins reading keyboard events
func (h *KeyboardHandler) Start() {
	go h.readLoop()
}

// Stop stops the keyboard handler
func (h *KeyboardHandler) Stop() {
	close(h.stopChan)
	syscall.Close(h.fd)
}

// Events returns the channel for key events
func (h *KeyboardHandler) Events() <-chan KeyEvent {
	return h.eventChan
}

func (h *KeyboardHandler) readLoop() {
	buf := make([]byte, 24) // sizeof(input_event)
	
	for {
		select {
		case <-h.stopChan:
			return
		default:
		}
		
		n, err := syscall.Read(h.fd, buf)
		if err != nil || n < 24 {
			continue
		}
		
		// Parse event
		evType := binary.LittleEndian.Uint16(buf[16:18])
		evCode := binary.LittleEndian.Uint16(buf[18:20])
		evValue := int32(binary.LittleEndian.Uint32(buf[20:24]))
		
		if evType != EV_KEY {
			continue
		}
		
		// Update modifiers
		pressed := evValue != 0
		switch evCode {
		case KEY_LEFTCTRL:
			if pressed {
				h.modifiers |= MOD_CTRL
			} else {
				h.modifiers &^= MOD_CTRL
			}
		case KEY_LEFTSHIFT:
			if pressed {
				h.modifiers |= MOD_SHIFT
			} else {
				h.modifiers &^= MOD_SHIFT
			}
		case KEY_LEFTALT:
			if pressed {
				h.modifiers |= MOD_ALT
			} else {
				h.modifiers &^= MOD_ALT
			}
		case KEY_LEFTMETA:
			if pressed {
				h.modifiers |= MOD_SUPER
			} else {
				h.modifiers &^= MOD_SUPER
			}
		}
		
		// Send event
		select {
		case h.eventChan <- KeyEvent{
			Key:       evCode,
			Pressed:   pressed,
			Modifiers: h.modifiers,
		}:
		default:
		}
	}
}

// CheckHotkey checks if a hotkey combination is pressed
func (h *KeyboardHandler) CheckHotkey(ev KeyEvent, key uint16, mods uint32) bool {
	return ev.Key == key && ev.Pressed && (ev.Modifiers&mods) == mods
}

// Unsafe import for ioctl
import "unsafe"
