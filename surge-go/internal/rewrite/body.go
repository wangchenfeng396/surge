package rewrite

import (
	"bytes"
	"fmt"
	"regexp"

	"github.com/surge-proxy/surge-go/internal/config"
)

// BodyRule holds compiled regex and config for body rewrite
type BodyRule struct {
	Config   *config.BodyRewriteConfig
	URLRegex *regexp.Regexp
}

// BodyRewriter handles body rewrite rules
type BodyRewriter struct {
	rules []*BodyRule
}

// NewBodyRewriter creates a new Body rewriter
func NewBodyRewriter(configs []*config.BodyRewriteConfig) (*BodyRewriter, error) {
	var rules []*BodyRule
	for _, cfg := range configs {
		pattern, err := regexp.Compile(cfg.URLRegex)
		if err != nil {
			return nil, fmt.Errorf("invalid url regex %q: %v", cfg.URLRegex, err)
		}
		rules = append(rules, &BodyRule{
			Config:   cfg,
			URLRegex: pattern,
		})
	}
	return &BodyRewriter{rules: rules}, nil
}

// RewriteResponse modifies the response body if URL matches
// Returns unmodified body if no rules match or error occurs.
// Note: This reads the entire body into memory, which might be expensive for large files.
func (r *BodyRewriter) RewriteResponse(urlStr string, body []byte) []byte {
	// Filter rules that match the URL and are of type http-response
	var matchedRules []*BodyRule
	for _, rule := range r.rules {
		if rule.Config.Type == "http-response" && rule.URLRegex.MatchString(urlStr) {
			matchedRules = append(matchedRules, rule)
		}
	}

	if len(matchedRules) == 0 {
		return body
	}

	// Apply rewrites sequentially
	currentBody := body
	for _, rule := range matchedRules {
		if rule.Config.Mode == "regex" {
			// Regex replacement on body
			// We need to compile the ReplacementOld as a regex
			re, err := regexp.Compile(rule.Config.ReplacementOld)
			if err == nil {
				currentBody = re.ReplaceAll(currentBody, []byte(rule.Config.ReplacementNew))
			}
		} else {
			// Simple string replacement
			currentBody = bytes.ReplaceAll(currentBody, []byte(rule.Config.ReplacementOld), []byte(rule.Config.ReplacementNew))
		}
	}

	return currentBody
}

// Stream wrapper? For now, we assume full buffering as per implementation plan which usually implies simple buffering for MVP.
// Advanced implementation uses io.Reader wrapper.
