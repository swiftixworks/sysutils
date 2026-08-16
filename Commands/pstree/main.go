package main

import "fmt"
import "os"

type processRow struct {
	pid  string
	ppid string
	name string
}

func showProcess(rows []processRow, pid string, prefix string) {
	for _, row := range rows {
		if row.pid == pid {
			fmt.Println(prefix + row.name + "(" + row.pid + ")")
		}
	}
	for _, row := range rows {
		if row.ppid == pid {
			showProcess(rows, row.pid, prefix+"  ")
		}
	}
}

func main() {
	if len(os.Args) != 1 {
		fmt.Println("pstree: usage: pstree")
		os.Exit(2)
	}
	if !requireProcSchema("pstree") {
		os.Exit(1)
	}
	processes, status := readGuestFile("pstree", "/proc/processes")
	if status != 0 {
		os.Exit(status)
	}
	rows := []processRow{}
	lines := splitLines(processes)
	for index := 1; index < len(lines); index++ {
		fields := splitFields(lines[index])
		if len(fields) >= 9 {
			rows = append(rows, processRow{pid: fields[0], ppid: fields[1], name: joinFields(fields, 8)})
		}
	}
	for _, row := range rows {
		if row.ppid == "0" {
			showProcess(rows, row.pid, "")
		}
	}
}
