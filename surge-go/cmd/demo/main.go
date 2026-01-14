package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/surge-proxy/surge-go/internal/protocol"
	"github.com/surge-proxy/surge-go/internal/protocol/trojan"
	"github.com/surge-proxy/surge-go/internal/protocol/vless"
	"github.com/surge-proxy/surge-go/internal/protocol/vmess"
	"github.com/surge-proxy/surge-go/internal/server"
)

func main() {
	// Command line flags
	httpPort := flag.String("http", "127.0.0.1:8888", "HTTP proxy listen address")
	socks5Port := flag.String("socks5", "127.0.0.1:6582", "SOCKS5 proxy listen address")
	proxyType := flag.String("type", "direct", "Proxy type: direct, vmess, trojan, vless")
	proxyServer := flag.String("server", "", "Proxy server address")
	port := flag.Int("port", 0, "Proxy server port")
	uuid := flag.String("uuid", "", "UUID (for vmess/vless)")
	password := flag.String("password", "", "Password (for trojan)")
	flag.Parse()

	log.SetFlags(log.LstdFlags | log.Lshortfile)
	log.Println("Starting Surge Proxy Server (Demo)...")

	// Create dialer based on type
	var dialer protocol.Dialer
	var err error

	switch *proxyType {
	case "direct":
		dialer = protocol.NewDirectDialer("DIRECT")
		log.Println("Using DIRECT connection")

	case "vmess":
		if *proxyServer == "" || *port == 0 || *uuid == "" {
			log.Fatal("VMess requires -server, -port, and -uuid")
		}
		vmessCfg := &vmess.Config{
			Name:   "demo-vmess",
			Server: *proxyServer,
			Port:   *port,
			UUID:   *uuid,
			TLS:    true,
		}
		dialer, err = vmess.NewClient(vmessCfg)
		if err != nil {
			log.Fatalf("Failed to create VMess client: %v", err)
		}
		log.Printf("Using VMess proxy: %s:%d", *proxyServer, *port)

	case "trojan":
		if *proxyServer == "" || *port == 0 || *password == "" {
			log.Fatal("Trojan requires -server, -port, and -password")
		}
		trojanCfg := &trojan.Config{
			Name:     "demo-trojan",
			Server:   *proxyServer,
			Port:     *port,
			Password: *password,
		}
		dialer, err = trojan.NewClient(trojanCfg)
		if err != nil {
			log.Fatalf("Failed to create Trojan client: %v", err)
		}
		log.Printf("Using Trojan proxy: %s:%d", *proxyServer, *port)

	case "vless":
		if *proxyServer == "" || *port == 0 || *uuid == "" {
			log.Fatal("VLESS requires -server, -port, and -uuid")
		}
		vlessCfg := &vless.Config{
			Name:   "demo-vless",
			Server: *proxyServer,
			Port:   *port,
			UUID:   *uuid,
			TLS:    true,
		}
		dialer, err = vless.NewClient(vlessCfg)
		if err != nil {
			log.Fatalf("Failed to create VLESS client: %v", err)
		}
		log.Printf("Using VLESS proxy: %s:%d", *proxyServer, *port)

	default:
		log.Fatalf("Unknown proxy type: %s", *proxyType)
	}

	// Test the dialer
	log.Println("Testing proxy connection...")
	ctx, cancel := context.WithTimeout(context.Background(), 10*1000000000) // 10 seconds
	defer cancel()
	testConn, err := dialer.DialContext(ctx, "tcp", "www.google.com:80")
	if err != nil {
		log.Printf("Warning: Proxy test failed: %v", err)
	} else {
		testConn.Close()
		log.Println("✓ Proxy connection test successful")
	}

	// Create HTTP proxy server
	httpServer := server.NewHTTPServerWithDialer(*httpPort, dialer)
	go func() {
		if err := httpServer.Start(); err != nil {
			log.Printf("HTTP server stopped: %v", err)
		}
	}()

	// Create SOCKS5 proxy server
	socks5Server := server.NewSOCKS5ServerWithDialer(*socks5Port, dialer)
	go func() {
		if err := socks5Server.Start(); err != nil {
			log.Printf("SOCKS5 server stopped: %v", err)
		}
	}()

	log.Println("✓ Proxy servers started successfully")
	log.Printf("  HTTP Proxy:   %s", *httpPort)
	log.Printf("  SOCKS5 Proxy: %s", *socks5Port)
	log.Println("\nProxy server is ready!")
	log.Println("Press Ctrl+C to stop...")

	// Wait for interrupt signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	<-sigChan

	fmt.Println("\nShutting down...")
	httpServer.Stop()
	socks5Server.Stop()
	log.Println("Server stopped")
}
