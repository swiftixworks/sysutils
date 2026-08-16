package main

import "fmt"
import "os"

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
		if !isDecimal(target) {
			usage()
		}
	}
	if !requireProcSchema("lsof") {
		os.Exit(1)
	}

	processes, status := readGuestFile("lsof", "/proc/processes")
	if status != 0 {
		os.Exit(status)
	}
	fmt.Println("PID NAME FD TYPE ACCESS FLAGS OFFSET SIZE DETAIL")
	found := false
	lines := splitLines(processes)
	for index := 1; index < len(lines); index++ {
		processFields := splitFields(lines[index])
		if len(processFields) < 9 {
			continue
		}
		pid := processFields[0]
		if target != "" && pid != target {
			continue
		}
		found = true
		name := joinFields(processFields, 8)
		descriptors, descriptorStatus := readGuestFile("lsof", "/proc/"+pid+"/fdinfo")
		if descriptorStatus != 0 {
			continue
		}
		descriptorLines := splitLines(descriptors)
		for descriptorIndex := 1; descriptorIndex < len(descriptorLines); descriptorIndex++ {
			fields := splitFields(descriptorLines[descriptorIndex])
			if len(fields) >= 7 {
				fmt.Println(pid, name, fields[0], fields[1], fields[2], fields[3], fields[4], fields[5], joinFields(fields, 6))
			}
		}
	}
	if target != "" && !found {
		fmt.Println("lsof: process not found")
		os.Exit(1)
	}
}
