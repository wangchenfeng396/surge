package main

import (
	"context"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/surge-proxy/surge-go/internal/api"
	"github.com/surge-proxy/surge-go/internal/config"
	"github.com/surge-proxy/surge-go/internal/engine"
	"github.com/surge-proxy/surge-go/internal/server"
)

func main() {
	configPath := flag.String("c", "surge.conf", "Path to Surge configuration file")
	testMode := flag.Bool("t", false, "Test configuration and exit")
	flag.Parse()

	log.SetFlags(log.LstdFlags | log.Lshortfile)
	log.Println("Starting Surge Proxy Server (Native Backend)...")

	var cfg *config.SurgeConfig

	if _, err := os.Stat(*configPath); err == nil {
		log.Printf("Loading Surge config from %s...", *configPath)
		content, err := ioutil.ReadFile(*configPath)
		if err != nil {
			log.Fatalf("Failed to read Surge config: %v", err)
		}

		// Parse config
		cfg, err = config.ParseConfig(string(content))
		if err != nil {
			log.Fatalf("Failed to parse config: %v", err)
		}
		log.Println("✓ Configuration loaded and parsed")

		if *testMode {
			log.Println("Configuration OK")
			return
		}
	} else {
		if *configPath != "surge.conf" {
			log.Fatalf("Config file not found: %s", *configPath)
		}
		log.Println("Using default configuration (empty)")
		cfg = config.NewSurgeConfig()
	}

	// Initialize Engine
	eng := engine.NewEngine(cfg)

	// Start Engine
	if err := eng.Start(); err != nil {
		log.Fatalf("Failed to start engine: %v", err)
	}
	log.Println("✓ Engine started successfully")

	// Initialize Proxy Servers
	// TODO: Get ports from config
	httpPort := 8888
	socksPort := 8889

	var rewriter server.Rewriter
	if eng.URLRewriter != nil {
		rewriter = eng.URLRewriter
	}
	var bodyRewriter server.BodyRewriter
	if eng.BodyRewriter != nil {
		bodyRewriter = eng.BodyRewriter
	}
	var mitm server.MITM
	if eng.MITMManager != nil {
		mitm = eng.MITMManager
	}

	httpServer := server.NewHTTPServer(fmt.Sprintf(":%d", httpPort), eng, rewriter, bodyRewriter, mitm)
	socksServer := server.NewSOCKS5Server(fmt.Sprintf(":%d", socksPort), eng)

	// Start Servers
	go func() {
		log.Printf("HTTP Proxy listening on :%d", httpPort)
		if err := httpServer.Start(); err != nil {
			log.Printf("HTTP Proxy error: %v", err)
		}
	}()

	go func() {
		log.Printf("SOCKS5 Proxy listening on :%d", socksPort)
		if err := socksServer.Start(); err != nil {
			log.Printf("SOCKS5 Proxy error: %v", err)
		}
	}()

	// Start API server
	apiServer := api.NewServer(eng, *configPath)
	go func() {
		if err := apiServer.Start(); err != nil {
			log.Fatalf("Failed to start API server: %v", err)
		}
	}()

	log.Println("Surge Proxy Server started successfully")
	log.Printf("Proxy: http://127.0.0.1:%d", httpPort)
	apiAddr := ":9090"
	if cfg.General.HTTPAPI != "" {
		apiAddr = cfg.General.HTTPAPI
	}
	log.Printf("API Server: http://%s", apiAddr)

	// Wait for interrupt signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	<-sigChan

	log.Println("Shutting down...")

	// Create shutdown context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	var wg sync.WaitGroup
	wg.Add(3)

	go func() {
		defer wg.Done()
		if err := httpServer.Shutdown(ctx); err != nil {
			log.Printf("HTTP server shutdown error: %v", err)
		}
	}()

	go func() {
		defer wg.Done()
		if err := socksServer.Shutdown(ctx); err != nil {
			log.Printf("SOCKS5 server shutdown error: %v", err)
		}
	}()

	go func() {
		defer wg.Done()
		if err := eng.Shutdown(ctx); err != nil {
			log.Printf("Engine shutdown error: %v", err)
		}
	}()

	done := make(chan struct{})
	go func() {
		wg.Wait()
		close(done)
	}()

	select {
	case <-done:
		log.Println("Graceful shutdown completed")
	case <-ctx.Done():
		log.Println("Shutdown timed out, forcing exit")
	}
}
