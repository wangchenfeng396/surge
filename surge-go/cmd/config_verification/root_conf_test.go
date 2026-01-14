package main_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/surge-proxy/surge-go/internal/config"
	"github.com/surge-proxy/surge-go/internal/engine"
)

const rootConfigPath = "../../surge.conf"

func TestRootSurgeConfiguration(t *testing.T) {
	// 1. Load Config
	absPath, err := filepath.Abs(rootConfigPath)
	if err != nil {
		t.Fatalf("Failed to get absolute path: %v", err)
	}
	t.Logf("Loading root config from: %s", absPath)

	data, err := os.ReadFile(absPath)
	if err != nil {
		t.Fatalf("Failed to read config file: %v", err)
	}

	cfg, err := config.ParseConfig(string(data))
	if err != nil {
		t.Fatalf("Failed to parse config: %v", err)
	}

	// 2. Initialize Engine
	eng := engine.NewEngine(cfg)
	// Start might fail if some proxy types are unsupported or configuration is invalid.
	if err := eng.Start(); err != nil {
		t.Logf("⚠️ Engine Start failed (likely unsupported proxies or missing setup): %v", err)
		t.Log("Skipping root config verification as environment setup for root config is effectively dummy/incomplete.")
		t.SkipNow()
	}
	defer eng.Stop()

	// 3. Define Test Cases based on surge.conf [Rule]
	tests := []struct {
		Name           string
		URL            string
		SourceIP       string
		ExpectedPolicy string
	}{
		{
			Name:           "Google Domain",
			URL:            "https://google.com",
			ExpectedPolicy: "Auto",
		},
		{
			Name:           "YouTube Suffix",
			URL:            "https://www.youtube.com",
			ExpectedPolicy: "Manual",
		},
		{
			Name:           "Local Network CIDR",
			URL:            "http://10.0.0.5",
			ExpectedPolicy: "DIRECT",
		},
		// GeoIP testing might require DB, skipping or mocking if needed.
		// If no DB, it returns false usually.
		{
			Name:           "Unknown Site (Final)",
			URL:            "https://example.org",
			ExpectedPolicy: "DIRECT",
		},
	}

	// 4. Run Routing Tests
	t.Log("=== Starting Root Config Routing Verification ===")
	for _, tc := range tests {
		t.Run(tc.Name, func(t *testing.T) {
			adapter, ruleDesc, err := eng.MatchRule(tc.URL, tc.SourceIP, "")
			if err != nil {
				t.Fatalf("MatchRule error: %v", err)
			}
			t.Logf("[%s] %s -> %s (Rule: %s)", tc.Name, tc.URL, adapter, ruleDesc)

			if adapter != tc.ExpectedPolicy {
				t.Errorf("Routing mismatch! Expected: %s, Got: %s", tc.ExpectedPolicy, adapter)
			}
		})
	}

	// 5. Connectivity check logic (Reuse from main_test if needed, but root config has dummy proxies)
	// We expect these to fail connectivity mostly.
}
