package policy

import (
	"context"
	"testing"

	"github.com/surge-proxy/surge-go/internal/protocol"
)

func TestSmartGroup(t *testing.T) {
	proxies := map[string]protocol.Dialer{
		"Stable":   &MockDialer{NameVal: "Stable", LatencyMs: 100},
		"Unstable": &MockDialer{NameVal: "Unstable", LatencyMs: 50}, // Lower latency but will fail
	}
	resolver := func(name string) protocol.Dialer {
		return proxies[name]
	}

	g := NewSmartGroup("Smart", []string{"Unstable", "Stable"}, resolver, "http://test.com", 0, false)

	// Initial retest to populate latency
	g.Retest()

	// Should pick Unstable (50ms vs 100ms)
	if g.Now() != "Unstable" {
		t.Errorf("expected Unstable, got %s", g.Now())
	}

	// Simulate failure on Unstable
	g.DialContext(context.Background(), "tcp", "fail")
	// Since MockDialer doesn't actually error unless Fail=true, we need to inject error manually?
	// But DialContext calls SafeDial which calls child.DialContext.
	// We need Unstable to fail.

	proxies["Unstable"].(*MockDialer).Fail = true

	_, err := g.DialContext(context.Background(), "tcp", "target")
	if err == nil {
		t.Error("expected error from Unstable")
	}

	// updateStats is called async in DialContext error path?
	// Wait, updateStats calls evaluate in background.
	// We need to wait a bit.

	// Better test: call updateStats directly or ensure evaluate runs.
	// But for integration, let's just trigger retest.

	// Since Unstable failed, FailureCount increments. Score increases.
	// Unstable: 50 + 2000 = 2050
	// Stable: 100 + 0 = 100
	// Should switch to Stable.

	// Manual evaluation trigger for deterministic test
	g.evaluate()

	if g.Now() != "Stable" {
		t.Errorf("expected Stable after failure, got %s", g.Now())
	}
}
