package config

import (
	"bufio"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"
)

// RulesetManager handles downloading and caching of rule sets
type RulesetManager struct {
	cache  map[string][]string
	mu     sync.RWMutex
	client *http.Client
}

var (
	globalRulesetManager *RulesetManager
	onceRuleset          sync.Once
)

// GetRulesetManager returns the singleton instance
func GetRulesetManager() *RulesetManager {
	onceRuleset.Do(func() {
		globalRulesetManager = &RulesetManager{
			cache: make(map[string][]string),
			client: &http.Client{
				Timeout: 30 * time.Second,
			},
		}
	})
	return globalRulesetManager
}

// GetRuleset retrieves a rule set from URL or cache
func (rm *RulesetManager) GetRuleset(url string) ([]string, error) {
	rm.mu.RLock()
	if rules, ok := rm.cache[url]; ok {
		rm.mu.RUnlock()
		return rules, nil
	}
	rm.mu.RUnlock()

	// Download
	resp, err := rm.client.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("failed to download ruleset, status: %d", resp.StatusCode)
	}

	var rules []string
	scanner := bufio.NewScanner(resp.Body)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line != "" && !strings.HasPrefix(line, "#") && !strings.HasPrefix(line, "//") {
			rules = append(rules, line)
		}
	}

	if err := scanner.Err(); err != nil && err != io.EOF {
		return nil, err
	}

	rm.mu.Lock()
	rm.cache[url] = rules
	rm.mu.Unlock()

	return rules, nil
}
