package rewrite

import (
	"testing"

	"github.com/surge-proxy/surge-go/internal/config"
)

func TestBodyRewriter(t *testing.T) {
	configs := []*config.BodyRewriteConfig{
		{
			Type:           "http-response",
			URLRegex:       `^http://example\.com/api`,
			ReplacementOld: "Foo",
			ReplacementNew: "Bar",
			Mode:           "simple",
		},
		{
			Type:           "http-response",
			URLRegex:       `^http://example\.com/regex`,
			ReplacementOld: `User-Id: \d+`,
			ReplacementNew: "User-Id: REDACTED",
			Mode:           "regex",
		},
	}

	rw, err := NewBodyRewriter(configs)
	if err != nil {
		t.Fatalf("Failed to create rewriter: %v", err)
	}

	tests := []struct {
		url      string
		body     string
		wantBody string
	}{
		{
			url:      "http://example.com/api/v1",
			body:     `{"data": "Foo"}`,
			wantBody: `{"data": "Bar"}`,
		},
		{
			url:      "http://example.com/regex/test",
			body:     `Header\nUser-Id: 12345\nEnd`,
			wantBody: `Header\nUser-Id: REDACTED\nEnd`,
		},
		{
			url:      "http://other.com/api",
			body:     `{"data": "Foo"}`,
			wantBody: `{"data": "Foo"}`,
		},
	}

	for _, tt := range tests {
		gotBody := rw.RewriteResponse(tt.url, []byte(tt.body))
		if string(gotBody) != tt.wantBody {
			t.Errorf("RewriteResponse(%q) = %q, want %q", tt.url, gotBody, tt.wantBody)
		}
	}
}
