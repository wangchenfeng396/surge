package rule

import (
	"fmt"
	"sync"

	"github.com/surge-proxy/surge-go/internal/config"
)

// Engine manages lifecycle and matching of rules
type Engine struct {
	rules []Rule
	mu    sync.RWMutex
}

// NewEngine creates a new rule engine
func NewEngine() *Engine {
	return &Engine{
		rules: make([]Rule, 0),
	}
}

// Add appends a rule to the engine
func (e *Engine) Add(r Rule) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.rules = append(e.rules, r)
}

// LoadFromConfig loads rules from configuration lines
func (e *Engine) LoadFromConfig(ruleLines []string) error {
	e.mu.Lock()
	defer e.mu.Unlock()

	var rules []Rule
	for _, line := range ruleLines {
		rule, err := ParseRule(line)
		if err != nil {
			// We might want to return error or just log and continue?
			// Surge usually stops or warns. Let's return error for now.
			return fmt.Errorf("failed to parse rule line '%s': %v", line, err)
		}
		if rule != nil {
			rules = append(rules, rule)

			// If it's a RULE-SET, start its auto-update?
			// Ideally we should manage this better, but for now simple start is ok.
			if rs, ok := rule.(*RuleSetRule); ok {
				// Start auto update every 24h by default, or configurable
				// Need update-interval logic which is usually in the config line options.
				// For now hardcode or skip.
				// We can just trigger a download now in background.
				go func() {
					_ = rs.UpdateFromURL()
				}()
			}
		}
	}
	e.rules = rules
	return nil
}

// LoadRulesFromConfigs loads rules from RuleConfig objects
func (e *Engine) LoadRulesFromConfigs(configs []*config.RuleConfig) error {
	e.mu.Lock()
	defer e.mu.Unlock()

	var rules []Rule
	for _, cfg := range configs {
		rule, err := CreateRuleFromConfig(cfg.Type, cfg.Value, cfg.Policy, cfg.NoResolve, cfg.Enabled, cfg.Comment)
		if err != nil {
			return fmt.Errorf("failed to create rule from config: %v", err)
		}
		if rule != nil {
			rules = append(rules, rule)

			if rs, ok := rule.(*RuleSetRule); ok {
				go func() {
					_ = rs.UpdateFromURL()
				}()
			}
		}
	}
	e.rules = rules
	return nil
}

// GetRules returns all loaded rules
func (e *Engine) GetRules() []Rule {
	e.mu.RLock()
	defer e.mu.RUnlock()
	// Return a copy or direct slice? Direct slice is risky if modified concurrently, but for read-only it's ok.
	// API usually serializes it immediately.
	// Let's return the slice, as we have configured handlers to be read-only on the rule objects essentially.
	// But slice itself is copy-by-value (pointer to array), so it's safe-ish.
	copied := make([]Rule, len(e.rules))
	copy(copied, e.rules)
	return copied
}

// ResetCounters resets hit counts for all rules
func (e *Engine) ResetCounters() {
	e.mu.Lock()
	defer e.mu.Unlock()
	for _, r := range e.rules {
		r.ResetHitCount()
	}
}

// ToggleRule toggles the enabled state of a rule by index
func (e *Engine) ToggleRule(index int, enabled bool) error {
	e.mu.Lock()
	defer e.mu.Unlock()

	if index < 0 || index >= len(e.rules) {
		return fmt.Errorf("rule index out of bounds: %d", index)
	}

	e.rules[index].SetEnabled(enabled)
	return nil
}

// Match finds the first matching rule for the request
func (e *Engine) Match(metadata *RequestMetadata) (string, Rule) {
	e.mu.RLock()
	defer e.mu.RUnlock()

	for _, r := range e.rules {
		if !r.IsEnabled() {
			continue
		}
		if r.Match(metadata) {
			r.IncrementHitCount()
			return r.Adapter(), r
		}
	}

	// No match found - technically should hit FINAL if present.
	// If no match and no FINAL, usually Direct or error.
	return "", nil
}

// Count returns number of loaded rules
func (e *Engine) Count() int {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return len(e.rules)
}
