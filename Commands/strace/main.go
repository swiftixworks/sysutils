package main

import "fmt"
import "os"

func main() {
	if len(os.Args) != 2 || !isDecimal(os.Args[1]) {
		fmt.Println("strace: usage: strace pid")
		os.Exit(2)
	}
	if !requireProcSchema("strace") {
		os.Exit(1)
	}
	trace, status := readGuestFile("strace", "/proc/"+os.Args[1]+"/syscalls")
	if status != 0 {
		os.Exit(status)
	}
	fmt.Println("# model swift-native-completed history=128")
	fmt.Print(trace)
}
