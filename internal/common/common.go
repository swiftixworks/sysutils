// Package common is the code every Swiftix sysutils command shares: reading
// the teaching procfs, checking its schema version, and splitting its
// line-and-field text.
package common

import "fmt"
import "swiftix/userland"

// procSchema is the teaching procfs schema these commands understand. It
// matches procfsSchemaVersion in package.json.
const procSchema = "1"

// SplitLines returns the lines of text without their newline terminators. A
// final line needs no terminator, and a trailing newline adds no empty line.
func SplitLines(text string) []string {
	result := []string{}
	start := 0
	for index := 0; index < len(text); index++ {
		if text[index] == 10 {
			result = append(result, text[start:index])
			start = index + 1
		}
	}
	if start < len(text) {
		result = append(result, text[start:])
	}
	return result
}

// isSpace reports whether value is a space, tab, newline, or carriage return.
func isSpace(value byte) bool {
	return value == 32 || value == 9 || value == 10 || value == 13
}

// SplitFields returns the runs of non-blank bytes in text, in order.
func SplitFields(text string) []string {
	result := []string{}
	start := -1
	for index := 0; index < len(text); index++ {
		if isSpace(text[index]) {
			if start >= 0 {
				result = append(result, text[start:index])
				start = -1
			}
		} else if start < 0 {
			start = index
		}
	}
	if start >= 0 {
		result = append(result, text[start:])
	}
	return result
}

// JoinFields joins fields[first:] with single spaces. It restores a value,
// such as a process name, that SplitFields broke at its blanks.
func JoinFields(fields []string, first int) string {
	result := ""
	for index := first; index < len(fields); index++ {
		if result != "" {
			result = result + " "
		}
		result = result + fields[index]
	}
	return result
}

// ReadGuestFile returns the contents of path with status 0. When the file
// cannot be read it reports the failure on behalf of command and returns a
// nonzero status.
func ReadGuestFile(command string, path string) (string, int) {
	return userland.ReadInput(command, []string{path})
}

// IsDecimal reports whether text is a nonempty run of ASCII digits.
func IsDecimal(text string) bool {
	if len(text) == 0 {
		return false
	}
	for index := 0; index < len(text); index++ {
		if text[index] < 48 || text[index] > 57 {
			return false
		}
	}
	return true
}

// RequireProcSchema reports whether /proc/swiftix declares the teaching procfs
// schema these commands understand. Otherwise it prints a diagnostic on behalf
// of command and returns false.
func RequireProcSchema(command string) bool {
	text, status := ReadGuestFile(command, "/proc/swiftix")
	if status != 0 {
		return false
	}
	for _, line := range SplitLines(text) {
		fields := SplitFields(line)
		if len(fields) == 2 && fields[0] == "ProcSchema:" && fields[1] == procSchema {
			return true
		}
	}
	fmt.Println(command + ": unsupported Swiftix teaching procfs schema")
	return false
}

// ValueAfterLabel returns the field that follows label on the first line of
// text that starts with it, or "?" when no line does.
func ValueAfterLabel(text string, label string) string {
	for _, line := range SplitLines(text) {
		fields := SplitFields(line)
		if len(fields) >= 2 && fields[0] == label {
			return fields[1]
		}
	}
	return "?"
}
