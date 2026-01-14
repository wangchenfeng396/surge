package dns

import (
	"context"
	"net"
	"testing"
)

// MockResolver for testing
type MockResolver struct {
	IPs map[string][]net.IP
	Err error
}

func (r *MockResolver) LookupIP(ctx context.Context, host string) ([]net.IP, error) {
	if r.Err != nil {
		return nil, r.Err
	}
	if ips, ok := r.IPs[host]; ok {
		return ips, nil
	}
	return nil, nil // Or error?
}

func (r *MockResolver) Test(ctx context.Context) (map[string]int, error) {
	return nil, nil
}

func (r *MockResolver) Close() error { return nil }

func TestHostsResolver(t *testing.T) {
	hosts := map[string]string{
		"localhost":  "127.0.0.1",
		"test.com":   "1.2.3.4",
		"*.wild.com": "5.6.7.8",
	}
	r := NewHostsResolver(hosts)

	tests := []struct {
		host string
		want string
	}{
		{"localhost", "127.0.0.1"},
		{"test.com", "1.2.3.4"},
		{"TEST.COM", "1.2.3.4"}, // Case insensitive
		{"unknown", ""},
		{"sub.wild.com", "5.6.7.8"},
		{"nested.sub.wild.com", "5.6.7.8"},
	}

	for _, tt := range tests {
		ips, err := r.LookupIP(context.Background(), tt.host)
		if tt.want != "" {
			if err != nil {
				t.Errorf("LookupIP(%q) error = %v", tt.host, err)
			} else if len(ips) == 0 || ips[0].String() != tt.want {
				t.Errorf("LookupIP(%q) = %v, want %v", tt.host, ips, tt.want)
			}
		} else {
			if err == nil {
				t.Errorf("LookupIP(%q) expected error, got %v", tt.host, ips)
			}
		}
	}
}

func TestManager(t *testing.T) {
	// Mock hosts
	hosts := map[string]string{
		"static.local": "192.168.1.1",
	}

	// Create Manager with no upstream/DoH
	mgr := NewManager(hosts, nil, nil, nil)

	// Inject Mock System Resolver
	mockSys := &MockResolver{
		IPs: map[string][]net.IP{
			"example.com": {net.ParseIP("93.184.216.34")},
		},
	}
	mgr.system = mockSys

	// Test Static (Hosts) - Should hit HostsResolver
	ips, err := mgr.LookupIP(context.Background(), "static.local")
	if err != nil || len(ips) == 0 || ips[0].String() != "192.168.1.1" {
		t.Errorf("Manager static lookup failed: %v, %v", ips, err)
	}

	// Test System (Mock) - Should hit MockResolver
	ips2, err := mgr.LookupIP(context.Background(), "example.com")
	if err != nil {
		t.Errorf("Manager system lookup error: %v", err)
	} else if len(ips2) == 0 || ips2[0].String() != "93.184.216.34" {
		t.Errorf("Manager system lookup mismatch: got %v", ips2)
	}

	// Test Cache Integration
	// "example.com" should now be in cache.
	// Let's clear mock and request again.
	// If it works, it came from cache.
	mockSys.IPs = nil
	ips3, err := mgr.LookupIP(context.Background(), "example.com")
	if err != nil || len(ips3) == 0 {
		t.Error("Manager failed to retrieve from cache")
	}

	// Test AlwaysRealIP
	mgr2 := NewManager(nil, nil, nil, []string{"real.com", "sub.net"})
	if !mgr2.IsAlwaysRealIP("real.com") {
		t.Error("real.com should be RealIP")
	}
	if !mgr2.IsAlwaysRealIP("foo.real.com") {
		t.Error("foo.real.com should be RealIP (suffix match)")
	}
	if mgr2.IsAlwaysRealIP("fake.com") {
		t.Error("fake.com should NOT be RealIP")
	}
}
