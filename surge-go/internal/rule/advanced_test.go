package rule

import (
	"testing"
)

func TestProtocolRule(t *testing.T) {
	r := NewProtocolRule("TCP", "Proxy", false)

	if !r.Match(&RequestMetadata{Type: "tcp"}) {
		t.Error("should match tcp")
	}
	if !r.Match(&RequestMetadata{Type: "tcp4"}) {
		t.Error("should match tcp4")
	}
	if r.Match(&RequestMetadata{Type: "udp"}) {
		t.Error("should not match udp")
	}
}

func TestDestPortRule(t *testing.T) {
	r, err := NewDestPortRule("80", "Proxy", false)
	if err != nil {
		t.Fatalf("failed to create rule: %v", err)
	}

	if !r.Match(&RequestMetadata{Port: 80}) {
		t.Error("should match port 80")
	}
	if r.Match(&RequestMetadata{Port: 443}) {
		t.Error("should not match port 443")
	}
}

func TestAndRule(t *testing.T) {
	// AND, ((PROTOCOL,TCP), (DEST-PORT,80)), Proxy
	pRule := NewProtocolRule("TCP", "", false)
	dRule, _ := NewDestPortRule("80", "", false)

	andRule := NewAndRule([]Rule{pRule, dRule}, "Proxy", false)

	if !andRule.Match(&RequestMetadata{Type: "tcp", Port: 80}) {
		t.Error("should match TCP AND Port 80")
	}
	if andRule.Match(&RequestMetadata{Type: "udp", Port: 80}) {
		t.Error("should not match UDP AND Port 80")
	}
	if andRule.Match(&RequestMetadata{Type: "tcp", Port: 443}) {
		t.Error("should not match TCP AND Port 443")
	}
}
