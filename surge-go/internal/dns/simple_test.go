package dns

import (
	"context"
	"fmt"
	"net"
	"testing"
	"time"

	"github.com/miekg/dns"
)

// StartMockDNSServer starts a local DNS server for testing
func StartMockDNSServer(t *testing.T, entries map[string]string) (*dns.Server, string) {
	pc, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("Failed to listen: %v", err)
	}
	addr := pc.LocalAddr().String()

	server := &dns.Server{
		PacketConn: pc,
		Handler: dns.HandlerFunc(func(w dns.ResponseWriter, r *dns.Msg) {
			m := new(dns.Msg)
			m.SetReply(r)
			m.Authoritative = true

			for _, q := range r.Question {
				name := q.Name
				if ip, ok := entries[name]; ok {
					rr, err := dns.NewRR(fmt.Sprintf("%s A %s", name, ip))
					if err == nil {
						m.Answer = append(m.Answer, rr)
					}
				}
			}
			w.WriteMsg(m)
		}),
	}

	go func() {
		server.ActivateAndServe()
	}()

	return server, addr
}

func TestSimpleResolver_Basic(t *testing.T) {
	entries := map[string]string{
		"example.com.": "1.2.3.4",
	}
	server, addr := StartMockDNSServer(t, entries)
	defer server.Shutdown()

	cfg := &Config{
		Servers: []string{addr},
		Timeout: 500 * time.Millisecond,
	}
	r := NewSimpleResolver(cfg)
	defer r.Close()

	ctx := context.Background()
	ips, err := r.LookupIP(ctx, "example.com")
	if err != nil {
		t.Fatalf("LookupIP failed: %v", err)
	}
	if len(ips) == 0 || ips[0].String() != "1.2.3.4" {
		t.Errorf("Expected 1.2.3.4, got %v", ips)
	}
}

func TestSimpleResolver_Retry(t *testing.T) {
	entries := map[string]string{
		"retry.com.": "5.6.7.8",
	}
	server, addr := StartMockDNSServer(t, entries)
	defer server.Shutdown()

	// First server is invalid/down, second is valid
	// Use a port that rejects or drops? 127.0.0.1:1 usually rejects.
	cfg := &Config{
		Servers: []string{"127.0.0.1:54321", addr},
		Timeout: 200 * time.Millisecond,
	}
	r := NewSimpleResolver(cfg)
	defer r.Close()

	ctx := context.Background()
	start := time.Now()
	ips, err := r.LookupIP(ctx, "retry.com")
	duration := time.Since(start)

	if err != nil {
		t.Fatalf("LookupIP failed with retry: %v", err)
	}
	if len(ips) == 0 || ips[0].String() != "5.6.7.8" {
		t.Errorf("Expected 5.6.7.8, got %v", ips)
	}

	// Verify it actually tried and timed out/failed quickly?
	// Since we use 127.0.0.1:54321 which is likely closed, it should fail fast (ICMP Refused).
	// If we used a blackhole IP, it would take Timeout.
	t.Logf("Resolution took %v", duration)
}
