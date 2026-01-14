package policy

import (
	"context"
	"fmt"
	"net"
	"sync"
	"testing"
	"time"

	"github.com/surge-proxy/surge-go/internal/protocol"
)

// MockDialer implements protocol.Dialer for testing
type MockDialer struct {
	NameVal    string
	LatencyMs  int
	Fail       bool
	LastDialed time.Time
	mu         sync.Mutex
}

func (m *MockDialer) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	m.mu.Lock()
	m.LastDialed = time.Now()
	m.mu.Unlock()
	if m.Fail {
		return nil, fmt.Errorf("mock fail")
	}
	return &net.TCPConn{}, nil
}
func (m *MockDialer) Name() string { return m.NameVal }
func (m *MockDialer) Type() string { return "mock" }
func (m *MockDialer) Test(url string, timeout time.Duration) (int, error) {
	if m.Fail {
		return 0, fmt.Errorf("mock fail")
	}
	return m.LatencyMs, nil
}
func (m *MockDialer) Close() error { return nil }

func TestSelectGroup(t *testing.T) {
	proxies := map[string]protocol.Dialer{
		"ProxyA": &MockDialer{NameVal: "ProxyA"},
		"ProxyB": &MockDialer{NameVal: "ProxyB"},
	}
	resolver := func(name string) protocol.Dialer {
		return proxies[name]
	}

	g := NewSelectGroup("Select", []string{"ProxyA", "ProxyB"}, resolver, "")

	if g.Now() != "ProxyA" {
		t.Errorf("default selection should be first proxy, got %s", g.Now())
	}

	if err := g.SetCurrent("ProxyB"); err != nil {
		t.Errorf("failed to set current: %v", err)
	}
	if g.Now() != "ProxyB" {
		t.Errorf("selection should update to ProxyB")
	}

	if err := g.SetCurrent("Invalid"); err == nil {
		t.Error("should error when setting invalid proxy")
	}

	// Test Dial
	_, err := g.DialContext(context.Background(), "tcp", "example.com:80")
	if err != nil {
		t.Errorf("dial failed: %v", err)
	}

	// Check if ProxyB was dialed
	pb := proxies["ProxyB"].(*MockDialer)
	if pb.LastDialed.IsZero() {
		t.Error("ProxyB was not dialed")
	}
}

func TestURLTestGroup(t *testing.T) {
	proxies := map[string]protocol.Dialer{
		"Fast": &MockDialer{NameVal: "Fast", LatencyMs: 50},
		"Slow": &MockDialer{NameVal: "Slow", LatencyMs: 200},
		"Dead": &MockDialer{NameVal: "Dead", Fail: true},
	}
	resolver := func(name string) protocol.Dialer {
		return proxies[name]
	}

	g := NewURLTestGroup("Auto", []string{"Slow", "Fast", "Dead"}, resolver, "http://test.com", 0, 0)

	// Default is first
	if g.Now() != "Slow" {
		t.Errorf("initial should be Slow, got %s", g.Now())
	}

	// Trigger retest manually
	g.Retest()

	if g.Now() != "Fast" {
		t.Errorf("after retest should be Fast, got %s", g.Now())
	}

	// Test Tolerance
	// Current is Fast (50).
	// Change Fast to 100. Change Slow to 80.
	// New Best is Slow (80 vs 100).
	// If Tolerance is 50. 80 > 100 - 50 (50). True. Should keep Fast?
	// Wait logic: bestLat (80) > curLat (100) - Tolerance (50) ?
	// 80 > 50. True. Return (Keep Current).
	// Yes.

	gWithTol := NewURLTestGroup("AutoTol", []string{"Cur", "NewBest"}, resolver, "http://test.com", 0, 50)
	proxies["Cur"] = &MockDialer{NameVal: "Cur", LatencyMs: 100}
	proxies["NewBest"] = &MockDialer{NameVal: "NewBest", LatencyMs: 80}

	// Force set current to Cur
	// URLTestGroup doesn't expose SetCurrent, it's internal.
	// But init config sets first as current.
	// So Cur is current.

	gWithTol.Retest()
	if gWithTol.Now() != "Cur" {
		t.Errorf("should keep Cur due to tolerance. Got %s", gWithTol.Now())
	}

	// Make NewBest much faster
	proxies["NewBest"].(*MockDialer).LatencyMs = 20
	// 20 > 100 - 50 (50). False. Should Switch.

	gWithTol.Retest()
	if gWithTol.Now() != "NewBest" {
		t.Errorf("should switch to NewBest. Got %s", gWithTol.Now())
	}
}
