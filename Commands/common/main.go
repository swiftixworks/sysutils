package main

import "fmt"
import "swiftix/userland"

func splitLines(text string) []string {
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

func isSpace(value int) bool {
	return value == 32 || value == 9 || value == 10 || value == 13
}

func splitFields(text string) []string {
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

func joinFields(fields []string, first int) string {
	result := ""
	for index := first; index < len(fields); index++ {
		if result != "" {
			result = result + " "
		}
		result = result + fields[index]
	}
	return result
}

func readGuestFile(command string, path string) (string, int) {
	text, status := userland.ReadInput(command, []string{path})
	return text, status
}

func isDecimal(text string) bool {
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

func requireProcSchema(command string) bool {
	text, status := readGuestFile(command, "/proc/swiftix")
	if status != 0 {
		return false
	}
	for _, line := range splitLines(text) {
		fields := splitFields(line)
		if len(fields) == 2 && fields[0] == "ProcSchema:" && fields[1] == "1" {
			return true
		}
	}
	fmt.Println(command + ": unsupported Swiftix teaching procfs schema")
	return false
}

func valueAfterLabel(text string, label string) string {
	for _, line := range splitLines(text) {
		fields := splitFields(line)
		if len(fields) >= 2 && fields[0] == label {
			return fields[1]
		}
	}
	return "?"
}
