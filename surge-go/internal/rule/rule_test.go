package rule

import (
	"net"
	"testing"
)

func TestDomainRule(t *testing.T) {
	r := NewDomainRule("google.com", "Proxy")

	if !r.Match(&RequestMetadata{Host: "google.com"}) {
		t.Error("should match exact domain")
	}
	if !r.Match(&RequestMetadata{Host: "Google.COM"}) {
		t.Error("should match case-insensitive")
	}
	if r.Match(&RequestMetadata{Host: "www.google.com"}) {
		t.Error("should not match subdomain for DOMAIN rule")
	}
}

func TestDomainSuffixRule(t *testing.T) {
	r := NewDomainSuffixRule("google.com", "Proxy")

	if !r.Match(&RequestMetadata{Host: "google.com"}) {
		t.Error("should match exact domain")
	}
	if !r.Match(&RequestMetadata{Host: "www.google.com"}) {
		t.Error("should match subdomain")
	}
	if r.Match(&RequestMetadata{Host: "agoogle.com"}) {
		t.Error("should not match partial suffix without dot")
	}
}

func TestDomainKeywordRule(t *testing.T) {
	r := NewDomainKeywordRule("google", "Proxy")

	if !r.Match(&RequestMetadata{Host: "google.com"}) {
		t.Error("should match keyword")
	}
	if !r.Match(&RequestMetadata{Host: "agoogle.com"}) {
		t.Error("should match keyword inside word")
	}
	if r.Match(&RequestMetadata{Host: "bing.com"}) {
		t.Error("should not match unrelated domain")
	}
}

func TestIPCIDRRule(t *testing.T) {
	r, err := NewIPCIDRRule("192.168.0.0/16", "Proxy", true)
	if err != nil {
		t.Fatalf("failed to create rule: %v", err)
	}

	if !r.Match(&RequestMetadata{IP: net.ParseIP("192.168.1.1")}) {
		t.Error("should match IP in CIDR")
	}
	if r.Match(&RequestMetadata{IP: net.ParseIP("10.0.0.1")}) {
		t.Error("should not match IP outside CIDR")
	}
}

func TestFinalRule(t *testing.T) {
	r := NewFinalRule("Proxy")
	if !r.Match(&RequestMetadata{}) {
		t.Error("FINAL should match everything")
	}
}
