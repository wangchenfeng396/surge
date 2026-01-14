package protocol

import (
	"context"
	"testing"
	"time"
)

func TestProxyConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *ProxyConfig
		wantErr bool
	}{
		{
			name: "valid config",
			config: &ProxyConfig{
				Name:   "test-proxy",
				Type:   "vmess",
				Server: "example.com",
				Port:   443,
			},
			wantErr: false,
		},
		{
			name: "empty name",
			config: &ProxyConfig{
				Type:   "vmess",
				Server: "example.com",
				Port:   443,
			},
			wantErr: true,
		},
		{
			name: "empty type",
			config: &ProxyConfig{
				Name:   "test-proxy",
				Server: "example.com",
				Port:   443,
			},
			wantErr: true,
		},
		{
			name: "empty server",
			config: &ProxyConfig{
				Name: "test-proxy",
				Type: "vmess",
				Port: 443,
			},
			wantErr: true,
		},
		{
			name: "invalid port - zero",
			config: &ProxyConfig{
				Name:   "test-proxy",
				Type:   "vmess",
				Server: "example.com",
				Port:   0,
			},
			wantErr: true,
		},
		{
			name: "invalid port - too large",
			config: &ProxyConfig{
				Name:   "test-proxy",
				Type:   "vmess",
				Server: "example.com",
				Port:   99999,
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("ProxyConfig.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestProxyConfig_GetOptions(t *testing.T) {
	config := &ProxyConfig{
		Name:   "test",
		Type:   "vmess",
		Server: "example.com",
		Port:   443,
		Options: map[string]interface{}{
			"uuid":     "12345678-1234-1234-1234-123456789012",
			"alterId":  64,
			"security": "auto",
			"tls":      true,
		},
	}

	// Test GetString
	if uuid, ok := config.GetString("uuid"); !ok || uuid != "12345678-1234-1234-1234-123456789012" {
		t.Errorf("GetString(uuid) = %v, %v, want 12345678-1234-1234-1234-123456789012, true", uuid, ok)
	}

	// Test GetInt
	if alterId, ok := config.GetInt("alterId"); !ok || alterId != 64 {
		t.Errorf("GetInt(alterId) = %v, %v, want 64, true", alterId, ok)
	}

	// Test GetBool
	if tls, ok := config.GetBool("tls"); !ok || !tls {
		t.Errorf("GetBool(tls) = %v, %v, want true, true", tls, ok)
	}

	// Test missing key
	if _, ok := config.GetString("nonexistent"); ok {
		t.Error("GetString(nonexistent) should return false")
	}
}

func TestDirectDialer(t *testing.T) {
	dialer := NewDirectDialer("test-direct")

	if dialer.Name() != "test-direct" {
		t.Errorf("Name() = %v, want test-direct", dialer.Name())
	}

	if dialer.Type() != "direct" {
		t.Errorf("Type() = %v, want direct", dialer.Type())
	}

	ctx := context.Background()
	conn, err := dialer.DialContext(ctx, "tcp", "www.google.com:80")
	if err != nil {
		t.Fatalf("DialContext() error = %v", err)
	}
	defer conn.Close()

	if conn == nil {
		t.Error("DialContext() returned nil connection")
	}
}

func TestRejectDialer(t *testing.T) {
	dialer := NewRejectDialer("test-reject")

	if dialer.Name() != "test-reject" {
		t.Errorf("Name() = %v, want test-reject", dialer.Name())
	}

	if dialer.Type() != "reject" {
		t.Errorf("Type() = %v, want reject", dialer.Type())
	}

	ctx := context.Background()
	conn, err := dialer.DialContext(ctx, "tcp", "www.google.com:80")
	if err == nil {
		t.Error("DialContext() should return error")
	}
	if conn != nil {
		t.Error("DialContext() should return nil connection")
	}

	// Test should also fail
	_, err = dialer.Test("http://www.google.com", 5*time.Second)
	if err == nil {
		t.Error("Test() should return error")
	}
}

func TestSimpleConnectionManager(t *testing.T) {
	manager := NewSimpleConnectionManager()
	dialer := NewDirectDialer("test")

	// Check initial stats
	stats := manager.Stats()
	if stats.Active != 0 || stats.TotalOpened != 0 {
		t.Errorf("Initial stats incorrect: %+v", stats)
	}

	// Get a connection
	ctx := context.Background()
	conn, err := manager.Get(ctx, dialer, "tcp", "www.google.com:80")
	if err != nil {
		t.Fatalf("Get() error = %v", err)
	}

	// Check stats after opening
	stats = manager.Stats()
	if stats.Active != 1 || stats.TotalOpened != 1 {
		t.Errorf("Stats after Get: %+v", stats)
	}

	// Close connection
	conn.Close()

	// Check stats after closing
	stats = manager.Stats()
	if stats.Active != 0 || stats.TotalClosed != 1 {
		t.Errorf("Stats after Close: %+v", stats)
	}
}

func TestSimpleTester(t *testing.T) {
	tester := NewSimpleTester(10 * time.Second)
	dialer := NewDirectDialer("test")

	// Test single proxy
	result := tester.Test(context.Background(), dialer, "http://www.google.com/generate_204")
	if result == nil {
		t.Fatal("Test() returned nil result")
	}

	if result.ProxyName != "test" {
		t.Errorf("Result ProxyName = %v, want test", result.ProxyName)
	}

	if result.Error != nil {
		t.Logf("Test error: %v (may be expected in some environments)", result.Error)
	} else if result.Latency <= 0 {
		t.Error("Test latency should be positive")
	}
}

func TestSimpleTester_Multiple(t *testing.T) {
	tester := NewSimpleTester(10 * time.Second)
	dialers := []Dialer{
		NewDirectDialer("direct-1"),
		NewDirectDialer("direct-2"),
		NewRejectDialer("reject-1"),
	}

	results := tester.TestMultiple(context.Background(), dialers, "http://www.google.com/generate_204")
	if len(results) != 3 {
		t.Fatalf("Expected 3 results, got %d", len(results))
	}

	// Check that each result corresponds to correct dialer
	for i, result := range results {
		if result.ProxyName != dialers[i].Name() {
			t.Errorf("Result[%d] ProxyName = %v, want %v", i, result.ProxyName, dialers[i].Name())
		}
	}

	// Reject dialer should have error
	if results[2].Error == nil {
		t.Error("Reject dialer test should have error")
	}
}
