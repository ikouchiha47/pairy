package main

import (
	"bufio"
	"context"
	"log"
	"net"
	"os/signal"
	"sync"
	"syscall"
	"time"
)

var (
	clients   = make(map[net.Conn]struct{})
	clientsMu sync.Mutex
	// replicaIDCounter int64 = 1
)

func main() {
	listener, err := net.Listen("tcp", ":8080")
	if err != nil {
		log.Println("Error starting server:", err)
		return
	}

	defer listener.Close()
	log.Println("Server started on :8080")

	ctx, stop := signal.NotifyContext(
		context.Background(),
		syscall.SIGTERM, syscall.SIGABRT, syscall.SIGKILL,
	)
	defer stop()

	done := make(chan struct{})
	// Handle graceful shutdown
	go handleShutdown(done, listener)

	for {
		select {
		case <-ctx.Done():
			done <- struct{}{}
			return
		default:
			conn, err := listener.Accept()
			if err != nil {
				log.Println("Error accepting connection:", err)
				continue
			}

			clientsMu.Lock()
			clients[conn] = struct{}{}
			clientsMu.Unlock()

			go withRecovery(handleConnection)(conn)
		}
	}
}

func handleConnection(conn net.Conn) {
	defer func() {
		conn.Close()

		clientsMu.Lock()
		defer clientsMu.Unlock()

		delete(clients, conn)
	}()

	reader := bufio.NewReader(conn)
	conn.SetReadDeadline(time.Now().Add(5 * time.Minute)) // Set read timeout

	for {
		message, err := reader.ReadString('\n')
		if err != nil {
			log.Printf("Error reading from client: %v", err)
			return
		}
		log.Print("Received:", message)

		// if message == "get_replica_id\n" {
		// 	replicaID := generateReplicaID()
		// 	conn.Write([]byte(fmt.Sprintf("replica_id: %d\n", replicaID)))
		// 	continue
		// }

		broadcastMessage(message, conn)
	}
}

// func generateReplicaID() int64 {
// 	return atomic.AddInt64(&replicaIDCounter, 1)
// }

func broadcastMessage(message string, sender net.Conn) {
	clientsMu.Lock()
	defer clientsMu.Unlock()

	for client := range clients {
		if client != sender {
			_, err := client.Write([]byte(message))
			if err != nil {
				log.Printf("Error writing to client %v\n", err)
				client.Close()
				delete(clients, client)
			}
		}
	}
}

// gracefull server shutdown on SIGINT or SIGTERM
func handleShutdown(done chan struct{}, listener net.Listener) {
	// stop := make(chan os.Signal, 1)
	// signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)

	// <-stop // Wait for the signal
	<-done

	log.Println("Shutting down server...")

	// Close all client connections
	clientsMu.Lock()
	for client := range clients {
		client.Close()
		delete(clients, client)
	}
	clientsMu.Unlock()

	listener.Close()
	log.Println("Server stopped")
}

func withRecovery(next func(conn net.Conn)) func(conn net.Conn) {
	return func(conn net.Conn) {
		defer func() {
			if r := recover(); r != nil {
				log.Printf("Recovered from panic: %v", r)
			}
		}()
		next(conn)
	}
}
