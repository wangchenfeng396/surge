package policy

import (
	"testing"
)

func TestBaseGroup_Filter(t *testing.T) {
	g := &BaseGroup{}

	proxies := []string{"US-Proxy-1", "HK-Proxy-2", "JP-Proxy-3", "US-Proxy-4"}

	// Test case 1: No filter
	filtered := g.FilterProxies(proxies)
	if len(filtered) != 4 {
		t.Errorf("Expected 4 proxies, got %d", len(filtered))
	}

	// Test case 2: Set filter
	err := g.SetFilter("US.*")
	if err != nil {
		t.Fatalf("Failed to set filter: %v", err)
	}

	filtered = g.FilterProxies(proxies)
	if len(filtered) != 2 {
		t.Errorf("Expected 2 proxies, got %d", len(filtered))
	}
	if filtered[0] != "US-Proxy-1" || filtered[1] != "US-Proxy-4" {
		t.Errorf("Filter returned unexpected results: %v", filtered)
	}

	// Test case 3: Empty filter (reset)
	err = g.SetFilter("")
	if err != nil {
		t.Fatalf("Failed to clear filter: %v", err)
	}

	filtered = g.FilterProxies(proxies)
	if len(filtered) != 4 {
		t.Errorf("Expected 4 proxies after clear, got %d", len(filtered))
	}
}

func TestSelectGroup_UpdateWithFilter(t *testing.T) {
	g := NewSelectGroup("Select", nil, nil, "")

	// Set filter
	g.SetFilter("HK")

	proxies := []string{"US-1", "HK-1", "JP-1"}

	// Update
	g.UpdateProxies(proxies, nil)

	current := g.Proxies()
	if len(current) != 1 {
		t.Errorf("Expected 1 proxy, got %d", len(current))
	}
	if current[0] != "HK-1" {
		t.Errorf("Expected HK-1, got %v", current)
	}
}
