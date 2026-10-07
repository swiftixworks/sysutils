package main

import "fmt"
import "os"
import "swiftix/internal/common"

func main() {
	if len(os.Args) != 2 || !common.IsDecimal(os.Args[1]) {
		fmt.Println("strace: usage: strace pid")
		os.Exit(2)
	}
	if !common.RequireProcSchema("strace") {
		os.Exit(1)
	}
	trace, status := common.ReadGuestFile("strace", "/proc/"+os.Args[1]+"/syscalls")
	if status != 0 {
		os.Exit(status)
	}
	fmt.Println("# model swift-native-completed history=128")
	fmt.Print(trace)
}
