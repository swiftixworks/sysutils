// Package userland is a host-side stand-in for the Swiftix Go runtime package
// of the same import path, so standard Go tools can resolve and type-check the
// command sources. Inside Swiftix the runtime provides the real implementation
// and this file is never compiled.
package userland

import (
	"fmt"
	"io"
	"os"
)

// ReadInput returns the concatenated contents of the operands, reading
// standard input when there are none or for a "-" operand. The status is 1
// when any operand could not be read.
func ReadInput(name string, operands []string) (string, int) {
	if len(operands) == 0 {
		data, _ := io.ReadAll(os.Stdin)
		return string(data), 0
	}
	text := ""
	status := 0
	for _, operand := range operands {
		var data []byte
		var err error
		if operand == "-" {
			data, err = io.ReadAll(os.Stdin)
		} else {
			data, err = os.ReadFile(operand)
		}
		if err != nil {
			fmt.Fprintf(os.Stderr, "%s: %s: No such file\n", name, operand)
			status = 1
			continue
		}
		text += string(data)
	}
	return text, status
}

// ReadStdin returns the next chunk of standard input with status 0, or an
// empty chunk with status 1 at end of input.
func ReadStdin() (string, int) {
	buffer := make([]byte, 4096)
	count, err := os.Stdin.Read(buffer)
	if count == 0 || err != nil {
		return "", 1
	}
	return string(buffer[:count]), 0
}

// WriteFile creates or truncates path with data and returns 0, or 1 on failure.
func WriteFile(path, data string) int {
	if os.WriteFile(path, []byte(data), 0o644) != nil {
		return 1
	}
	return 0
}

// SetRawMode reports false: the host stand-in has no terminal control.
func SetRawMode(enabled bool) bool { return false }

// WindowSize reports (0, 0): the host stand-in has no terminal.
func WindowSize() (int, int) { return 0, 0 }
