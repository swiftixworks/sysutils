package main

import "fmt"
import "os"
import "swiftix/internal/common"

func usage() {
	fmt.Println("lsof: usage: lsof [pid]")
	os.Exit(2)
}

func main() {
	if len(os.Args) > 2 {
		usage()
	}
	target := ""
	if len(os.Args) == 2 {
		target = os.Args[1]
		if !common.IsDecimal(target) {
			usage()
		}
	}
	if !common.RequireProcSchema("lsof") {
		os.Exit(1)
	}

	processes, status := common.ReadGuestFile("lsof", "/proc/processes")
	if status != 0 {
		os.Exit(status)
	}
	fmt.Println("PID NAME FD TYPE ACCESS FLAGS OFFSET SIZE DETAIL")
	found := false
	lines := common.SplitLines(processes)
	for index := 1; index < len(lines); index++ {
		processFields := common.SplitFields(lines[index])
		if len(processFields) < 9 {
			continue
		}
		pid := processFields[0]
		if target != "" && pid != target {
			continue
		}
		found = true
		name := common.JoinFields(processFields, 8)
		// A process listed a moment ago may have exited since (a pipeline
		// neighbour, for instance); skip it without a diagnostic.
		descriptors, descriptorError := os.ReadFile("/proc/" + pid + "/fdinfo")
		if descriptorError != nil {
			continue
		}
		descriptorLines := common.SplitLines(string(descriptors))
		for descriptorIndex := 1; descriptorIndex < len(descriptorLines); descriptorIndex++ {
			fields := common.SplitFields(descriptorLines[descriptorIndex])
			if len(fields) >= 7 {
				fmt.Println(pid, name, fields[0], fields[1], fields[2], fields[3], fields[4], fields[5], common.JoinFields(fields, 6))
			}
		}
	}
	if target != "" && !found {
		fmt.Println("lsof: process not found")
		os.Exit(1)
	}
}
