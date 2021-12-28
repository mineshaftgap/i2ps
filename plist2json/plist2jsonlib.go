/*
 * See LICENSE for licensing information
 */
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
)

type Dict struct {
	array []*KeyPair
}

func (dict *Dict) add(keypair *KeyPair) {
	length := len(dict.array)

	n_arry := make([]*KeyPair, length+1)
	copy(n_arry, dict.array)
	dict.array = n_arry

	dict.array = dict.array[0 : length+1]
	dict.array[length] = keypair
}

func (dict *Dict) Print() {
	fmt.Print("{")

	length := len(dict.array)

	for i := 0; i < length; i++ {
		if i > 0 && i != length {
			fmt.Print(",")
		}

		dict.array[i].Print()
	}

	fmt.Print("}")
}

type KeyPair struct {
	key  string
	kind string
	str  string
	bool string
	int  int
	dict *Dict
}

// we use this struct so we can Marshal
type EncodeString struct {
	PlaceHolderKey string `json:"PlaceHolderKey"`
}

func (keypair *KeyPair) Print() {
	if keypair.kind == "string" || keypair.kind == "date" {
		// Use Marshal to encode for us
		bytes, err := json.Marshal(EncodeString{
			PlaceHolderKey: keypair.str,
		})
		if err != nil {
			fmt.Println("error:", err)
		}

		// replace the place holder
		jsonStr := strings.Replace(string(bytes), "PlaceHolderKey", keypair.key, 1)
		// strip off the begining "{" and ending "}"
		fmt.Print(jsonStr[1 : len(jsonStr)-1])
	} else {
		fmt.Print("\"" + keypair.key + "\": ")

		if keypair.kind == "bool" {
			fmt.Print(keypair.bool)
		} else if keypair.kind == "integer" {
			fmt.Print(keypair.int)
		} else if keypair.kind == "dict" {
			keypair.dict.Print()
		}
	}
}

func ReadPlist(f *os.File) *Dict {
	rd := bufio.NewReader(f)

	for {
		rune, size, err := rd.ReadRune()

		if err != nil {
			fmt.Println(err)
			break
		}

		if size > 1 {
			fmt.Println("Got Rune, but we don't support unicode yet!")
			break
		}

		if rune == '<' {
			st := getNextToken(rd, '>')
			if st == "/plist" {
				break
			}

			if st == "dict" {
				return readDict(rd)
			}
		}
	}

	return nil
}

func readDict(rd *bufio.Reader) *Dict {
	dict := new(Dict)
	var keypair *KeyPair

	for {
		rune, size, err := rd.ReadRune()
		if err != nil {
			fmt.Println(err)
			break
		}

		if size > 1 {
			fmt.Println("Got Rune, but we don't support unicode yet!")
			break
		}

		if rune == '<' {
			token := getNextToken(rd, '>')

			if token == "/dict" {
				break
			}

			if token == "key" {
				keypair = new(KeyPair)
				dict.add(keypair)
				token := getNextToken(rd, '<')
				keypair.key = token

				continue
			}

			if token == "dict" {
				keypair.kind = token
				keypair.dict = readDict(rd)

				continue
			}

			if token == "string" || token == "date" {
				keypair.kind = token
				token := getNextToken(rd, '<')
				keypair.str = token
			}

			if token == "integer" {
				keypair.kind = token
				token := getNextToken(rd, '<')
				is, err := strconv.Atoi(token)

				if err == nil {
					keypair.int = is
				} else {
					keypair.int = 0
				}
			}

			if token == "true/" {
				keypair.kind = "bool"
				keypair.bool = "true"
			}

			if token == "false/" {
				keypair.kind = "bool"
				keypair.bool = "false"
			}
		}
	}

	return dict
}

func getNextToken(rd *bufio.Reader, delim byte) string {
	str, err := rd.ReadString(delim)

	if err != nil {
		fmt.Println(err)
		return ""
	}

	str = str[:len(str)-1]

	return str
}
