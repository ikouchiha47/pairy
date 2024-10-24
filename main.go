package main

import (
	"bufio"
	"bytes"
	"log"
	"net"
	"strings"
	"sync"
)

var (
	clients   = make(map[net.Conn]struct{})
	clientsMu sync.Mutex
)

func main() {
	listener, err := net.Listen("tcp", ":8080")
	if err != nil {
		log.Println("Error starting server:", err)
		return
	}
	defer listener.Close()
	log.Println("Server started on :8080")

	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Println("Error accepting connection:", err)
			continue
		}

		clientsMu.Lock()
		clients[conn] = struct{}{}
		clientsMu.Unlock()

		go handleConnectionEOF(conn)
	}
}

func handleConnectionEOF(conn net.Conn) {
	defer conn.Close()

	var messageBuffer []byte

	for {
		buffer := make([]byte, 1024)
		n, err := conn.Read(buffer)
		if err != nil {
			log.Println("Error reading from connection:", err)
			return
		}

		messageBuffer = append(messageBuffer, buffer[:n]...)

		if bytes.Contains(messageBuffer, []byte("<EOF>")) {
			break // End of File
		}
	}

	message := string(messageBuffer)

	// replaced := strings.ReplaceAll(message, "<EOF>", "\n")
	// clientsMu.Lock()
	//
	// for client := range clients {
	// 	if client != conn {
	// 		client.Write([]byte(replaced))
	// 	}
	// }

	// clientsMu.Unlock()

	// Keep Replacing because we are replacing full buffer
	parts := strings.Split(message, "<EOF>")
	for _, part := range parts {
		if part != "" {
			log.Print("Received:", part)

			clientsMu.Lock()

			for client := range clients {
				if client != conn {
					client.Write([]byte(part))
				}
			}

			clientsMu.Unlock()
		}
	}
}

func handleConnection(conn net.Conn) {
	defer conn.Close()
	reader := bufio.NewReader(conn)

	for {
		message, err := reader.ReadString('\n')
		if err != nil {
			break
		}
		log.Print("Received:", message)

		// Broadcast message to all clients
		clientsMu.Lock()
		for client := range clients {
			if client != conn { // Don't send the message back to the sender
				_, err := client.Write([]byte(message))
				if err != nil {
					log.Printf("Error writing to client %v\n", err)
				}
			}
		}
		clientsMu.Unlock()
	}

	// Remove client from the list
	clientsMu.Lock()
	delete(clients, conn)
	clientsMu.Unlock()
}
