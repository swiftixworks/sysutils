package main

import "fmt"
import "os"

func main() {
	if len(os.Args) != 1 {
		fmt.Println("memstat: usage: memstat")
		os.Exit(2)
	}
	if !requireProcSchema("memstat") {
		os.Exit(1)
	}

	memory, status := readGuestFile("memstat", "/proc/meminfo")
	if status != 0 {
		os.Exit(status)
	}
	processes, processStatus := readGuestFile("memstat", "/proc/processes")
	if processStatus != 0 {
		os.Exit(processStatus)
	}

	fmt.Println("MODEL managed-runtime")
	fmt.Println("TOTAL_KB", valueAfterLabel(memory, "MemTotal:"))
	fmt.Println("USED_KB", valueAfterLabel(memory, "RuntimeHeap:"))
	fmt.Println("FREE_KB", valueAfterLabel(memory, "MemFree:"))
	fmt.Println("VFS_BYTES", valueAfterLabel(memory, "VFSFileBytes:"))
	fmt.Println("PID MEM NAME")
	lines := splitLines(processes)
	for index := 1; index < len(lines); index++ {
		fields := splitFields(lines[index])
		if len(fields) >= 9 {
			fmt.Println(fields[0], fields[7], joinFields(fields, 8))
		}
	}
}
