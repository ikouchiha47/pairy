package main

import (
	"bufio"
	"log"
	"net"
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

		go handleConnection(conn)
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
