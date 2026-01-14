package rule

import (
	"testing"
)

func TestParseRule(t *testing.T) {
	tests := []struct {
		line     string
		valid    bool
		ruleType string
		payload  string
		adapter  string
	}{
		{"DOMAIN,google.com,Proxy", true, "DOMAIN", "google.com", "Proxy"},
		{"DOMAIN-SUFFIX,google.com,Proxy", true, "DOMAIN-SUFFIX", "google.com", "Proxy"},
		{"IP-CIDR,127.0.0.0/8,Direct,no-resolve", true, "IP-CIDR", "127.0.0.0/8", "Direct"},
		{"FINAL,Proxy", true, "FINAL", "", "Proxy"},
		{"# Comment", false, "", "", ""},
		{"INVALID,something", false, "", "", ""},
	}

	for _, tt := range tests {
		r, err := ParseRule(tt.line)
		if tt.valid {
			if err != nil {
				t.Errorf("ParseRule(%q) failed: %v", tt.line, err)
				continue
			}
			if r.Type() != tt.ruleType {
				t.Errorf("ParseRule(%q) type = %v, want %v", tt.line, r.Type(), tt.ruleType)
			}
			if r.Payload() != tt.payload {
				t.Errorf("ParseRule(%q) payload = %v, want %v", tt.line, r.Payload(), tt.payload)
			}
			if r.Adapter() != tt.adapter {
				t.Errorf("ParseRule(%q) adapter = %v, want %v", tt.line, r.Adapter(), tt.adapter)
			}
		} else {
			if err == nil && r != nil {
				t.Errorf("ParseRule(%q) matched %v, want valid=false", tt.line, r.Type())
			}
		}
	}
}

func TestRuleSet(t *testing.T) {
	// Create a dummy ruleset rule
	rs, _ := NewRuleSetRule("http://example.com/rules", "Proxy", nil)

	// Manually inject rules for testing
	rs.Rules = []Rule{
		NewDomainRule("example.com", ""),
		NewDomainSuffixRule("test.com", ""),
	}

	if !rs.Match(&RequestMetadata{Host: "example.com"}) {
		t.Error("should match domain in ruleset")
	}
	if !rs.Match(&RequestMetadata{Host: "sub.test.com"}) {
		t.Error("should match suffix in ruleset")
	}
	if rs.Match(&RequestMetadata{Host: "other.com"}) {
		t.Error("should not match unrelated domain")
	}
}
