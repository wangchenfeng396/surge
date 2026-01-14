package rule

import (
	"testing"
)

func TestProcessNameRule_Match(t *testing.T) {
	tests := []struct {
		name        string
		rulePayload string
		processPath string
		want        bool
	}{
		{
			name:        "Exact match",
			rulePayload: "Discord",
			processPath: "/Applications/Discord.app/Contents/MacOS/Discord",
			want:        true,
		},
		{
			name:        "Case insensitive match",
			rulePayload: "discord",
			processPath: "/Applications/Discord.app/Contents/MacOS/Discord",
			want:        true,
		},
		{
			name:        "Mismatch",
			rulePayload: "Slack",
			processPath: "/Applications/Discord.app/Contents/MacOS/Discord",
			want:        false,
		},
		{
			name:        "Empty process path",
			rulePayload: "Discord",
			processPath: "",
			want:        false,
		},
		{
			name:        "Filename only match",
			rulePayload: "curl",
			processPath: "/usr/bin/curl",
			want:        true,
		},
		{
			name:        "Complex path match",
			rulePayload: "Google Chrome",
			processPath: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
			want:        true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := NewProcessNameRule(tt.rulePayload, "Proxy", false)
			metadata := &RequestMetadata{
				ProcessPath: tt.processPath,
			}
			if got := r.Match(metadata); got != tt.want {
				t.Errorf("ProcessNameRule.Match() = %v, want %v", got, tt.want)
			}
		})
	}
}
