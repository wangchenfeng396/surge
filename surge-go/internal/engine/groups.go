package engine

import (
	"fmt"

	"github.com/surge-proxy/surge-go/internal/config"
	"github.com/surge-proxy/surge-go/internal/policy"
	"github.com/surge-proxy/surge-go/internal/protocol"
)

// loadGroups loads policy groups from configuration
func (e *Engine) loadGroups(cfg *config.SurgeConfig) error {
	e.Groups = make(map[string]policy.Group)

	// We need a resolver that can look up proxies from:
	// 1. The already loaded Manual Proxies (e.Proxies)
	// 2. The other Groups (e.Groups) - though order matters?
	// Surge allows groups to reference other groups.
	// We typically load all groups first (as shells), then wire them up, OR reliance on lazy resolution.
	// Our ProxyResolver is `func(name string) protocol.Dialer`.
	// If it returns nil, dialing fails. It doesn't need to return valid object at creation time usually,
	// UNLESS the Group logic checks existence immediately.
	// SelectGroup/URLTestGroup usually store names and resolve at Dial time (SelectGroup) or Test time (URLTestGroup).
	// Checked implementation:
	// SelectGroup stores names. SafeDial calls resolver.
	// URLTestGroup stores names. Retest calls resolver.
	// So late binding is fine.

	resolver := func(name string) protocol.Dialer {
		// Check manual proxies
		if p, ok := e.Proxies[name]; ok {
			return p
		}
		// Check groups
		if g, ok := e.Groups[name]; ok {
			return g
		}
		// Check built-in
		if name == "DIRECT" {
			return protocol.NewDirectDialer("DIRECT")
		}
		if name == "REJECT" {
			// Rejection dialer?
			// We can return a specific dialer or let SafeDial handle it?
			// BaseGroup.SafeDial handles "REJECT" explicitly if resolver returns nil?
			// Let's check BaseGroup.SafeDial logic.
			// It checks childName == "REJECT" BEFORE calling resolver.
			// So returning nil here is fine for REJECT if caller handles it,
			// BUT if nested group uses it, it might pass through.
			// Ideally we return a RejectDialer if we have one.
			return nil
		}
		return nil
	}

	// Prepare list of all proxy names for IncludeAll support
	var allProxies []string
	for name := range e.Proxies {
		allProxies = append(allProxies, name)
	}

	// Load groups
	// Order matters for nesting? Validation comes later.
	for _, gConfig := range cfg.ProxyGroups {
		group, err := policy.NewGroupFromConfig(gConfig, resolver, allProxies)
		if err != nil {
			return fmt.Errorf("failed to create group %s: %v", gConfig.Name, err)
		}
		e.Groups[gConfig.Name] = group
	}

	// Validate dependencies
	if err := policy.ValidateCycles(e.Groups); err != nil {
		return fmt.Errorf("policy group cycle detected: %v", err)
	}

	return nil
}
