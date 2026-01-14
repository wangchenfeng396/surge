package server

import (
	"testing"
	"time"

	"github.com/surge-proxy/surge-go/internal/protocol"
)

func TestHTTPServer(t *testing.T) {
	// Create a test HTTP server with direct dialer
	dialer := protocol.NewDirectDialer("DIRECT")
	server := NewHTTPServerWithDialer("127.0.0.1:18888", dialer)

	// Start server in background
	go func() {
		if err := server.Start(); err != nil {
			t.Logf("Server stopped: %v", err)
		}
	}()

	// Give server time to start
	time.Sleep(100 * time.Millisecond)

	// Stop server
	if err := server.Stop(); err != nil {
		t.Errorf("Failed to stop server: %v", err)
	}
}

func TestSOCKS5Server(t *testing.T) {
	// Create a test SOCKS5 server with direct dialer
	dialer := protocol.NewDirectDialer("DIRECT")
	server := NewSOCKS5ServerWithDialer("127.0.0.1:18889", dialer)

	// Start server in background
	go func() {
		if err := server.Start(); err != nil {
			t.Logf("Server stopped: %v", err)
		}
	}()

	// Give server time to start
	time.Sleep(100 * time.Millisecond)

	// Stop server
	if err := server.Stop(); err != nil {
		t.Errorf("Failed to stop server: %v", err)
	}
}

func TestHTTPServerAddr(t *testing.T) {
	server := NewHTTPServerWithDialer("127.0.0.1:18890", nil)
	if server.Addr() != "127.0.0.1:18890" {
		t.Errorf("Addr() = %v, want 127.0.0.1:18890", server.Addr())
	}
}

func TestSOCKS5ServerAddr(t *testing.T) {
	server := NewSOCKS5ServerWithDialer("127.0.0.1:18891", nil)
	if server.Addr() != "127.0.0.1:18891" {
		t.Errorf("Addr() = %v, want 127.0.0.1:18891", server.Addr())
	}
}
