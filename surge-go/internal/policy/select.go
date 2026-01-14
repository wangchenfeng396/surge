package policy

import (
	"context"
	"fmt"
	"net"
	"sync"
	"time"

	"github.com/surge-proxy/surge-go/internal/protocol"
)

// SelectGroup implements a manually selectable policy group
type SelectGroup struct {
	BaseGroup
	current string
	mu      sync.RWMutex
}

func (g *SelectGroup) UpdateProxies(proxies []string, localProxies map[string]protocol.Dialer) {
	g.mu.Lock()
	defer g.mu.Unlock()

	// Apply filter
	proxies = g.FilterProxies(proxies)

	g.ProxiesList = proxies
	g.LocalProxies = localProxies

	// Reset current if valid? Or keep if possible?
	// If list changed, we should ensure current is valid.
	found := false
	for _, p := range proxies {
		if p == g.current {
			found = true
			break
		}
	}
	if !found && len(proxies) > 0 {
		g.current = proxies[0]
	} else if len(proxies) == 0 {
		g.current = ""
	}
}

// NewSelectGroup creates a new SelectGroup
func NewSelectGroup(name string, proxies []string, resolver ProxyResolver, initialSelected string) *SelectGroup {
	current := ""
	if len(proxies) > 0 {
		current = proxies[0]
	}

	// Try to use initial selection if valid
	if initialSelected != "" {
		for _, p := range proxies {
			if p == initialSelected {
				current = initialSelected
				break
			}
		}
	}

	return &SelectGroup{
		BaseGroup: BaseGroup{
			NameStr:     name,
			TypeStr:     "select",
			ProxiesList: proxies,
			Resolver:    resolver,
		},
		current: current,
	}
}

// DialContext implements protocol.Dialer
func (g *SelectGroup) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	g.mu.RLock()
	target := g.current
	g.mu.RUnlock()

	if target == "" {
		return nil, fmt.Errorf("no proxy selected in group %s", g.Name())
	}

	return g.SafeDial(ctx, network, address, target)
}

// Now returns the current selection
func (g *SelectGroup) Now() string {
	g.mu.RLock()
	defer g.mu.RUnlock()
	return g.current
}

// SetCurrent changes the current selection
func (g *SelectGroup) SetCurrent(name string) error {
	g.mu.Lock()
	defer g.mu.Unlock()

	// Validate if name is in list
	found := false
	for _, p := range g.ProxiesList {
		if p == name {
			found = true
			break
		}
	}
	// "DIRECT" and "REJECT" are special keywords that might be valid even if not in explicit list?
	// Usually they must be in the list for Select group.
	if !found {
		return fmt.Errorf("proxy '%s' not found in group %s", name, g.Name())
	}

	g.current = name
	return nil
}

// Test implements protocol.Dialer (tests the CURRENT proxy)
func (g *SelectGroup) Test(url string, timeout time.Duration) (int, error) {
	g.mu.RLock()
	target := g.current
	g.mu.RUnlock()

	if target == "" {
		return 0, fmt.Errorf("no proxy selected")
	}

	if g.Resolver != nil {
		child := g.Resolver(target)
		if child != nil {
			return child.Test(url, timeout)
		}
	}
	return 0, fmt.Errorf("cannot test proxy '%s'", target)
}
