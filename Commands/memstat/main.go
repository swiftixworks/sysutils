package main

import "fmt"
import "os"
import "swiftix/internal/common"

func main() {
	if len(os.Args) != 1 {
		fmt.Println("memstat: usage: memstat")
		os.Exit(2)
	}
	if !common.RequireProcSchema("memstat") {
		os.Exit(1)
	}

	memory, status := common.ReadGuestFile("memstat", "/proc/meminfo")
	if status != 0 {
		os.Exit(status)
	}
	processes, processStatus := common.ReadGuestFile("memstat", "/proc/processes")
	if processStatus != 0 {
		os.Exit(processStatus)
	}

	fmt.Println("MODEL managed-runtime")
	fmt.Println("TOTAL_KB", common.ValueAfterLabel(memory, "MemTotal:"))
	fmt.Println("USED_KB", common.ValueAfterLabel(memory, "RuntimeHeap:"))
	fmt.Println("FREE_KB", common.ValueAfterLabel(memory, "MemFree:"))
	fmt.Println("VFS_BYTES", common.ValueAfterLabel(memory, "VFSFileBytes:"))
	fmt.Println("PID MEM NAME")
	lines := common.SplitLines(processes)
	for index := 1; index < len(lines); index++ {
		fields := common.SplitFields(lines[index])
		if len(fields) >= 9 {
			fmt.Println(fields[0], fields[7], common.JoinFields(fields, 8))
		}
	}
}
