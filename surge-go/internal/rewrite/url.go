package rewrite

import (
	"fmt"
	"regexp"
	"strings"

	"github.com/surge-proxy/surge-go/internal/config"
)

// RewriteAction represents the action to take after rewriting
type RewriteAction int

const (
	ActionNone RewriteAction = iota
	ActionRedirect302
	ActionRedirect307
	ActionHeader
	ActionReject
)

// URLRule holds a compiled regex and config
type URLRule struct {
	Config  *config.URLRewriteConfig
	Pattern *regexp.Regexp
	Action  RewriteAction
}

// URLRewriter handles URL rewrite rules
type URLRewriter struct {
	rules []*URLRule
}

// NewURLRewriter creates a new URL rewriter
func NewURLRewriter(configs []*config.URLRewriteConfig) (*URLRewriter, error) {
	var rules []*URLRule
	for _, cfg := range configs {
		// Surge regex usually simple? Or full PCRE? Go uses RE2.
		// Assuming standard Go regexp compatibility.
		pattern, err := regexp.Compile(cfg.Regex)
		if err != nil {
			return nil, fmt.Errorf("invalid regex %q: %v", cfg.Regex, err)
		}

		action := ActionNone
		switch strings.ToLower(cfg.Type) {
		case "302":
			action = ActionRedirect302
		case "307":
			action = ActionRedirect307
		case "header":
			action = ActionHeader
		case "reject":
			action = ActionReject
		}

		rules = append(rules, &URLRule{
			Config:  cfg,
			Pattern: pattern,
			Action:  action,
		})
	}
	return &URLRewriter{rules: rules}, nil
}

// Rewrite check if url matches any rule and returns new url and action
func (r *URLRewriter) Rewrite(urlStr string) (string, RewriteAction) {
	for _, rule := range r.rules {
		if rule.Pattern.MatchString(urlStr) {
			// If reject, return immediately
			if rule.Action == ActionReject {
				return "", ActionReject
			}

			// Perform replacement
			// Go's ReplaceAllString handles $1, $2 expansion if using ${1} syntax usually?
			// Check regexp docs. ReplaceAllString expands $1.
			newURL := rule.Pattern.ReplaceAllString(urlStr, rule.Config.Replacement)

			return newURL, rule.Action
		}
	}
	return urlStr, ActionNone
}
