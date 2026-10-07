package main

import "fmt"
import "os"
import "swiftix/internal/common"

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
	if !common.RequireProcSchema("pstree") {
		os.Exit(1)
	}
	processes, status := common.ReadGuestFile("pstree", "/proc/processes")
	if status != 0 {
		os.Exit(status)
	}
	rows := []processRow{}
	lines := common.SplitLines(processes)
	for index := 1; index < len(lines); index++ {
		fields := common.SplitFields(lines[index])
		if len(fields) >= 9 {
			rows = append(rows, processRow{pid: fields[0], ppid: fields[1], name: common.JoinFields(fields, 8)})
		}
	}
	for _, row := range rows {
		if row.ppid == "0" {
			showProcess(rows, row.pid, "")
		}
	}
}
