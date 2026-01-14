package test

import (
	"context"
	"io"
	"net"
	"testing"

	"github.com/surge-proxy/surge-go/internal/config"
	"github.com/surge-proxy/surge-go/internal/engine"
	"github.com/surge-proxy/surge-go/internal/rule"
)

func BenchmarkRuleMatching(b *testing.B) {
	// Setup Rule Engine
	// Use manual setup or engine
	eng := rule.NewEngine()
	eng.Add(rule.NewDomainSuffixRule("google.com", "Proxy"))
	if r, err := rule.NewIPCIDRRule("192.168.0.0/16", "Direct", false); err == nil {
		eng.Add(r)
	}
	eng.Add(rule.NewFinalRule("Reject"))

	meta := &rule.RequestMetadata{
		Type: "tcp",
		Host: "www.google.com",
		Port: 443,
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		eng.Match(meta)
	}
}

func BenchmarkThroughput_Direct(b *testing.B) {
	// Direct TCP throughput (baseline)
	serverLn, _ := net.Listen("tcp", "127.0.0.1:0")
	addr := serverLn.Addr().String()
	go func() {
		for {
			conn, err := serverLn.Accept()
			if err != nil {
				return
			}
			go io.Copy(io.Discard, conn)
		}
	}()
	defer serverLn.Close()

	b.ResetTimer()
	b.SetBytes(1024 * 1024)

	for i := 0; i < b.N; i++ {
		conn, err := net.Dial("tcp", addr)
		if err != nil {
			b.Fatal(err)
		}

		// Send 1MB
		buf := make([]byte, 1024*1024)
		conn.Write(buf)
		conn.Close()
	}
}

func BenchmarkThroughput_Engine(b *testing.B) {
	// Setup Engine with ALL Direct
	cfgStr := `
[General]
loglevel = verbose
[Rule]
FINAL, DIRECT
`
	cfg, err := config.ParseConfig(cfgStr)
	if err != nil {
		b.Fatal(err)
	}
	eng := engine.NewEngine(cfg)
	eng.Start()
	defer eng.Stop()

	// Start Mock Dial Handler?
	// Engine default DIRECT dials standard net Dial.

	// Start Echo Server
	serverLn, _ := net.Listen("tcp", "127.0.0.1:0")
	targetAddr := serverLn.Addr().String()
	go func() {
		for {
			conn, err := serverLn.Accept()
			if err != nil {
				return
			}
			go io.Copy(io.Discard, conn)
		}
	}()
	defer serverLn.Close()

	b.ResetTimer()
	b.SetBytes(1024 * 1024)

	// host, portStr, _ := net.SplitHostPort(targetAddr)
	// port, _ := strconv.Atoi(portStr)

	for i := 0; i < b.N; i++ {
		// Use Engine.HandleRequest to get dialer
		dialer := eng.HandleRequest(context.Background(), "tcp", targetAddr, "")
		if dialer == nil {
			b.Fatal("nil dialer")
		}

		conn, err := dialer.DialContext(context.Background(), "tcp", targetAddr)
		if err != nil {
			b.Fatal(err)
		}

		buf := make([]byte, 1024*1024)
		conn.Write(buf)
		conn.Close()
	}
}
