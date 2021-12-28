/*
 * See LICENSE for licensing information
 */
package main

import (
	"flag"
	"fmt"
	"os"
)

// shamelessly borrowed from https://github.com/kutani/plist2json

// ./plist2json ../iTunesLibrary.xml |jq '.Tracks'|more

func usage() {
	fmt.Fprintf(os.Stderr, "Usage: plist2json [file ...]\n")
	os.Exit(2)
}

func main() {
	flag.Usage = usage
	flag.Parse()

	argv := flag.Args()
	stat, _ := os.Stdin.Stat()
	var plist *Dict

	// check if there is stdin
	if (stat.Mode() & os.ModeCharDevice) == 0 {
		plist = ReadPlist(os.Stdin)
		if plist == nil {
			fmt.Println("ERROR")
		} else {
			plist.Print()
		}
		// otherwise read from file
	} else if len(argv) > 0 {
		for _, path := range argv {
			file, err := os.Open(path)
			if err != nil {
				fmt.Fprintf(os.Stderr, "open %s: %s", path, err)
				continue
			}

			plist = ReadPlist(file)

			if plist == nil {
				fmt.Println("ERROR")
			} else {
				plist.Print()
			}

			file.Close()
		}
	} else {
		usage()
	}
}
