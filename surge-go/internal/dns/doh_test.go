package dns

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/miekg/dns"
)

func TestDoHResolver(t *testing.T) {
	// Start a mock DoH server
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			t.Errorf("Expected POST, got %s", r.Method)
			http.Error(w, "Method Not Allowed", 405)
			return
		}
		if r.Header.Get("Content-Type") != "application/dns-message" {
			t.Errorf("Expected Content-Type application/dns-message, got %s", r.Header.Get("Content-Type"))
		}

		body, err := io.ReadAll(r.Body)
		if err != nil {
			t.Fatalf("Failed to read body: %v", err)
		}

		var msg dns.Msg
		if err := msg.Unpack(body); err != nil {
			t.Fatalf("Failed to unpack DNS message: %v", err)
		}

		// Create response
		resp := new(dns.Msg)
		resp.SetReply(&msg)
		resp.Authoritative = true

		for _, q := range msg.Question {
			if q.Name == "example.com." && q.Qtype == dns.TypeA {
				rr, _ := dns.NewRR("example.com. A 1.1.1.1")
				resp.Answer = append(resp.Answer, rr)
			}
		}

		out, err := resp.Pack()
		if err != nil {
			t.Fatalf("Failed to pack response: %v", err)
		}

		w.Header().Set("Content-Type", "application/dns-message")
		w.Write(out)
	}))
	defer ts.Close()

	r := NewDoHResolver([]string{ts.URL})
	defer r.Close()

	ctx := context.Background()
	ips, err := r.LookupIP(ctx, "example.com")
	if err != nil {
		t.Fatalf("LookupIP failed: %v", err)
	}

	if len(ips) == 0 || ips[0].String() != "1.1.1.1" {
		t.Errorf("Expected 1.1.1.1, got %v", ips)
	}
}

func TestDoHResolver_Failover(t *testing.T) {
	// Good server
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Just verify it's called
		body, _ := io.ReadAll(r.Body)
		var msg dns.Msg
		msg.Unpack(body)

		resp := new(dns.Msg)
		resp.SetReply(&msg)
		rr, _ := dns.NewRR(fmt.Sprintf("%s A 2.2.2.2", msg.Question[0].Name))
		resp.Answer = append(resp.Answer, rr)

		out, _ := resp.Pack()
		w.Header().Set("Content-Type", "application/dns-message")
		w.Write(out)
	}))
	defer ts.Close()

	// Bad URL + Good URL
	r := NewDoHResolver([]string{"http://invalid.local:12345", ts.URL})

	ips, err := r.LookupIP(context.Background(), "failover.com")
	if err != nil {
		t.Fatalf("LookupIP failed with failover: %v", err)
	}
	if len(ips) == 0 || ips[0].String() != "2.2.2.2" {
		t.Errorf("Expected 2.2.2.2, got %v", ips)
	}
}
