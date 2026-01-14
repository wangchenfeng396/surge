package policy

import (
	"fmt"
	"regexp"
	"strings"

	"github.com/surge-proxy/surge-go/internal/config"
)

// FilterableGroup is a group that supports regex filtering
type FilterableGroup interface {
	SetFilter(regex string) error
	FilterProxies(proxies []string) []string
}

// NewGroupFromConfig creates a policy group from configuration
func NewGroupFromConfig(cfg *config.ProxyGroupConfig, resolver ProxyResolver, allProxies []string) (Group, error) {
	// Pre-process proxies:
	// 1. Start with configured proxies
	proxies := make([]string, len(cfg.Proxies))
	copy(proxies, cfg.Proxies)

	// 2. Add all proxies if include-all is enabled
	if cfg.IncludeAll {
		// Avoid duplicates? Configurable?
		// Usually we just append. Or we check if already exists.
		// For simplicity/performance, appending unique items.
		existing := make(map[string]bool)
		for _, p := range proxies {
			existing[p] = true
		}
		for _, p := range allProxies {
			if !existing[p] {
				proxies = append(proxies, p)
			}
		}
	}

	// 3. Apply regex filter if present
	var re *regexp.Regexp
	var err error

	if cfg.PolicyRegex != "" {
		re, err = regexp.Compile(cfg.PolicyRegex)
		if err != nil {
			return nil, fmt.Errorf("invalid policy regex '%s': %v", cfg.PolicyRegex, err)
		}

		var filtered []string
		for _, p := range proxies {
			if re.MatchString(p) {
				filtered = append(filtered, p)
			}
		}
		proxies = filtered
	}

	var g Group

	switch strings.ToLower(cfg.Type) {
	case "select":
		g = NewSelectGroup(cfg.Name, proxies, resolver, cfg.Selected)
	case "url-test":
		g = NewURLTestGroup(cfg.Name, proxies, resolver, cfg.URL, cfg.Interval, cfg.Tolerance)
	case "relay":
		g = NewRelayGroup(cfg.Name, proxies, resolver)
	case "smart":
		g = NewSmartGroup(cfg.Name, proxies, resolver, cfg.URL, cfg.Interval, cfg.EvaluateBeforeUse)
	// case "fallback": ...
	default:
		return nil, fmt.Errorf("unsupported group type: %s", cfg.Type)
	}

	// Set the filter on the group instance so future updates are also filtered
	if cfg.PolicyRegex != "" {
		if fg, ok := g.(FilterableGroup); ok {
			_ = fg.SetFilter(cfg.PolicyRegex) // Already validated
		}
	}

	// Handle Subscription (Dynamic Proxy Group)
	if cfg.PolicyPath != "" {
		if ug, ok := g.(UpdatableGroup); ok {
			// Default interval if not set (e.g. 86400)
			interval := cfg.UpdateInterval
			if interval == 0 {
				interval = 86400
			}
			fmt.Printf("Starting subscription for group %s url=%s interval=%d\n", cfg.Name, cfg.PolicyPath, interval)
			sub := NewSubscription(cfg.PolicyPath, interval, ug)
			sub.StartAutoUpdate()
			// Note: We don't store the subscription object anywhere explicit,
			// but the running goroutines will keep it alive and updating the group.
		} else {
			return nil, fmt.Errorf("group type %s does not support policy-path (subscription)", cfg.Type)
		}
	}

	return g, nil
}
