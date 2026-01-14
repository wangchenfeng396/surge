package rule

import (
	"testing"
)

func TestEngine(t *testing.T) {
	config := []string{
		"DOMAIN,example.com,Proxy",
		"DOMAIN-SUFFIX,google.com,Proxy,no-resolve",
		"IP-CIDR,10.0.0.0/8,Direct",
		"FINAL,Direct",
	}

	engine := NewEngine()
	if err := engine.LoadFromConfig(config); err != nil {
		t.Fatalf("failed to load config: %v", err)
	}

	if engine.Count() != 4 {
		t.Errorf("expected 4 rules, got %d", engine.Count())
	}

	tests := []struct {
		metadata    *RequestMetadata
		wantAdapter string
	}{
		{&RequestMetadata{Host: "example.com"}, "Proxy"},
		{&RequestMetadata{Host: "mail.google.com"}, "Proxy"},
		{&RequestMetadata{IP: []byte{10, 0, 0, 1}}, "Direct"},
		{&RequestMetadata{Host: "baidu.com"}, "Direct"}, // FINAL
	}

	for _, tt := range tests {
		adapter, _ := engine.Match(tt.metadata)
		if adapter != tt.wantAdapter {
			t.Errorf("Match(%v) = %v, want %v", tt.metadata, adapter, tt.wantAdapter)
		}
	}
}
