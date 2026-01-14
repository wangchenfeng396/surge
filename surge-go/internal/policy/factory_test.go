package policy

import (
	"testing"

	"github.com/surge-proxy/surge-go/internal/config"
)

func TestNewGroupFromConfig_SelectWithFilter(t *testing.T) {
	cfg := &config.ProxyGroupConfig{
		Name:        "SelectGroup",
		Type:        "select",
		Proxies:     []string{"US-1", "HK-1", "US-2", "JP-1"},
		PolicyRegex: "^US",
	}

	g, err := NewGroupFromConfig(cfg, nil, nil)
	if err != nil {
		t.Fatalf("Failed to create group: %v", err)
	}

	proxies := g.Proxies()
	if len(proxies) != 2 {
		t.Errorf("Expected 2 proxies, got %d", len(proxies))
	}
	for _, p := range proxies {
		if p != "US-1" && p != "US-2" {
			t.Errorf("Unexpected proxy in filtered group: %s", p)
		}
	}
}

func TestNewGroupFromConfig_URLTestWithFilter(t *testing.T) {
	cfg := &config.ProxyGroupConfig{
		Name:        "AutoGroup",
		Type:        "url-test",
		Proxies:     []string{"US-FAST", "HK-SLOW", "US-SLOW"},
		PolicyRegex: "FAST",
		URL:         "http://test.com",
		Interval:    300,
	}

	g, err := NewGroupFromConfig(cfg, nil, nil)
	if err != nil {
		t.Fatalf("Failed to create group: %v", err)
	}

	proxies := g.Proxies()
	if len(proxies) != 1 {
		t.Errorf("Expected 1 proxy, got %d", len(proxies))
	}
	if proxies[0] != "US-FAST" {
		t.Errorf("Expected US-FAST, got %s", proxies[0])
	}
}

func TestNewGroupFromConfig_IncludeAll(t *testing.T) {
	cfg := &config.ProxyGroupConfig{
		Name:       "AllGroup",
		Type:       "select",
		Proxies:    []string{"Manual-1"},
		IncludeAll: true,
	}

	allProxies := []string{"Proxy-A", "Proxy-B", "Manual-1"} // Manual-1 is duplicate

	g, err := NewGroupFromConfig(cfg, nil, allProxies)
	if err != nil {
		t.Fatalf("Failed to create group: %v", err)
	}

	proxies := g.Proxies()
	if len(proxies) != 3 {
		t.Errorf("Expected 3 proxies, got %d", len(proxies))
	}
	// Verify Manual-1 appears, and duplicate handled (if implementation deduplicates)
	// Current impl deduplicates.

	hasA := false
	hasB := false
	manualCount := 0
	for _, p := range proxies {
		if p == "Proxy-A" {
			hasA = true
		}
		if p == "Proxy-B" {
			hasB = true
		}
		if p == "Manual-1" {
			manualCount++
		}
	}

	if !hasA || !hasB || manualCount != 1 {
		t.Errorf("Proxies list incorrect: %v", proxies)
	}
}

func TestNewGroupFromConfig_InvalidRegex(t *testing.T) {
	cfg := &config.ProxyGroupConfig{
		Name:        "BadRegex",
		Type:        "select",
		Proxies:     []string{"A", "B"},
		PolicyRegex: "[Invalid",
	}

	_, err := NewGroupFromConfig(cfg, nil, nil)
	if err == nil {
		t.Error("Expected error for invalid regex, got nil")
	}
}
