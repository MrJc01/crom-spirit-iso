// Package input handles low-level Linux input events
// Reading directly from /dev/input/event* devices
package input

import (
	"encoding/binary"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// InputEvent represents a Linux input_event struct
type InputEvent struct {
	TimeSec  uint64
	TimeUsec uint64
	Type     uint16
	Code     uint16
	Value    int32
}

const (
	// Event types
	EV_SYN = 0x00
	EV_KEY = 0x01
	EV_REL = 0x02 // Relative (mouse movement)
	EV_ABS = 0x03 // Absolute (touchscreen)

	// Relative axes
	REL_X = 0x00
	REL_Y = 0x01

	// Key states
	KEY_RELEASE = 0
	KEY_PRESS   = 1
	KEY_REPEAT  = 2
)

// EvdevReader reads events from a /dev/input device
type EvdevReader struct {
	file *os.File
	path string
}

// FindMouseDevice scans /dev/input for a mouse device
func FindMouseDevice() (string, error) {
	matches, err := filepath.Glob("/dev/input/event*")
	if err != nil {
		return "", err
	}

	for _, path := range matches {
		// Try to identify mouse by reading capabilities
		// For simplicity, we check if "mouse" is in the device name symlink
		// A more robust solution would read EVIOCGBIT ioctls
		symlink := "/sys/class/input/" + filepath.Base(path) + "/device/name"
		name, err := os.ReadFile(symlink)
		if err == nil && strings.Contains(strings.ToLower(string(name)), "mouse") {
			return path, nil
		}
	}

	// Fallback to event0 (common default)
	if len(matches) > 0 {
		return matches[0], nil
	}

	return "", fmt.Errorf("no input devices found")
}

// NewEvdevReader opens an input device
func NewEvdevReader(path string) (*EvdevReader, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("failed to open %s: %w", path, err)
	}
	return &EvdevReader{file: file, path: path}, nil
}

// ReadEvent reads the next input event (blocking)
func (r *EvdevReader) ReadEvent() (*InputEvent, error) {
	event := &InputEvent{}
	err := binary.Read(r.file, binary.LittleEndian, event)
	if err != nil {
		return nil, err
	}
	return event, nil
}

// Close closes the device file
func (r *EvdevReader) Close() error {
	return r.file.Close()
}
