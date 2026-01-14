package rule

import (
	"bufio"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

// RuleSetRule matches against a set of rules loaded from external source
type RuleSetRule struct {
	BaseRule
	URL      string
	Rules    []Rule
	UpdateMu sync.RWMutex
}

// NewRuleSetRule creates a new rule set.
// Note: It DOES NOT block to download rules immediately.
// Rules should be loaded asynchronously or explicitly.
func NewRuleSetRule(url, adapter string, initialRules []Rule) (*RuleSetRule, error) {
	return &RuleSetRule{
		BaseRule: BaseRule{
			RuleType:    "RULE-SET",
			RulePayload: url,
			AdapterName: adapter,
		},
		URL:   url,
		Rules: initialRules,
	}, nil
}

func (r *RuleSetRule) Match(metadata *RequestMetadata) bool {
	r.UpdateMu.RLock()
	defer r.UpdateMu.RUnlock()

	for _, rule := range r.Rules {
		if rule.Match(metadata) {
			return true
		}
	}
	return false
}

// UpdateFromURL downloads and parsing the ruleset
func (r *RuleSetRule) UpdateFromURL() error {
	// 1. Download
	// For local files
	var reader io.Reader
	if strings.HasPrefix(r.URL, "file://") {
		f, err := os.Open(strings.TrimPrefix(r.URL, "file://"))
		if err != nil {
			return err
		}
		defer f.Close()
		reader = f
	} else {
		// Assume HTTP/HTTPS
		resp, err := http.Get(r.URL)
		if err != nil {
			return err
		}
		defer resp.Body.Close()
		if resp.StatusCode != 200 {
			return fmt.Errorf("failed to download ruleset: status %d", resp.StatusCode)
		}
		reader = resp.Body
	}

	// 2. Parse
	var rules []Rule
	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") || strings.HasPrefix(line, "//") {
			continue
		}

		// Parse rule line
		// RuleSets often don't have adapter in the line, or they might.
		// Typically: DOMAIN-SUFFIX,google.com
		// The adapter is determined by the RULE-SET line in the main config.
		// So we pass empty adapter to ParseRule?
		// But ParseRule expects standard format which might include adapter.
		// If the line is "DOMAIN-SUFFIX,google.com", split len is 2.
		// ParseRule handles it (adapter will be empty).

		rule, err := ParseRule(line)
		if err != nil {
			// Log error but continue?
			continue
		}
		if rule != nil {
			rules = append(rules, rule)
		}
	}

	r.UpdateMu.Lock()
	r.Rules = rules
	r.UpdateMu.Unlock()

	return nil
}

// StartAutoUpdate starts a background routine to update rules
func (r *RuleSetRule) StartAutoUpdate(interval time.Duration) {
	go func() {
		// Initial update
		_ = r.UpdateFromURL()

		ticker := time.NewTicker(interval)
		for range ticker.C {
			_ = r.UpdateFromURL()
		}
	}()
}
