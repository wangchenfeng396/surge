package dns

import (
	"net"
	"testing"
	"time"
)

func TestCache_Stats(t *testing.T) {
	c := NewCache(1 * time.Minute)

	// Miss
	if ips := c.Get("miss.com"); ips != nil {
		t.Error("Expected nil for miss")
	}

	// Set
	c.Set("hit.com", []net.IP{net.ParseIP("1.2.3.4")})

	// Hit
	if ips := c.Get("hit.com"); len(ips) == 0 {
		t.Error("Expected IPs for hit")
	}

	hits, misses := c.Stats()
	if hits != 1 {
		t.Errorf("Expected 1 hit, got %d", hits)
	}
	if misses != 1 {
		t.Errorf("Expected 1 miss, got %d", misses)
	}
}

func TestCache_Expiry(t *testing.T) {
	c := NewCache(100 * time.Millisecond) // Short TTL
	c.Set("expire.com", []net.IP{net.ParseIP("1.1.1.1")})

	// Hit immediately
	if ips := c.Get("expire.com"); len(ips) == 0 {
		t.Error("Should hit immediately")
	}

	time.Sleep(200 * time.Millisecond)

	// Miss after expiry
	if ips := c.Get("expire.com"); ips != nil {
		t.Error("Should miss after expiry")
	}

	_, misses := c.Stats()
	if misses != 1 {
		t.Errorf("Expected 1 miss (expired), got %d", misses)
	}
}
