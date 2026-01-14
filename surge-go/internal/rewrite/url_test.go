package rewrite

import (
	"testing"

	"github.com/surge-proxy/surge-go/internal/config"
)

func TestURLRewriter(t *testing.T) {
	configs := []*config.URLRewriteConfig{
		{
			Regex:       `^https?://www\.google\.cn`,
			Replacement: "https://www.google.com",
			Type:        "302",
		},
		{
			Regex:       `^http://(www\.)?example\.com/foo/(.*)`,
			Replacement: "http://example.com/bar/$2",
			Type:        "header",
		},
		{
			Regex:       `^http://ad\.doubleclick\.net/.*`,
			Replacement: "", // Reject usually doesn't need replacement
			Type:        "reject",
		},
	}

	rw, err := NewURLRewriter(configs)
	if err != nil {
		t.Fatalf("Failed to create rewriter: %v", err)
	}

	tests := []struct {
		url        string
		wantURL    string
		wantAction RewriteAction
	}{
		{
			url:        "http://www.google.cn",
			wantURL:    "https://www.google.com",
			wantAction: ActionRedirect302,
		},
		{
			url:        "http://example.com/foo/baz?q=1",
			wantURL:    "http://example.com/bar/baz?q=1",
			wantAction: ActionHeader,
		},
		{
			url:        "http://ad.doubleclick.net/ad/123",
			wantURL:    "",
			wantAction: ActionReject,
		},
		{
			url:        "https://www.bing.com",
			wantURL:    "https://www.bing.com",
			wantAction: ActionNone,
		},
	}

	for _, tt := range tests {
		gotURL, gotAction := rw.Rewrite(tt.url)
		if gotURL != tt.wantURL {
			t.Errorf("Rewrite(%q) URL = %q, want %q", tt.url, gotURL, tt.wantURL)
		}
		if gotAction != tt.wantAction {
			t.Errorf("Rewrite(%q) Action = %v, want %v", tt.url, gotAction, tt.wantAction)
		}
	}
}
