package policy

import (
	"context"
	"fmt"
	"net"
	"regexp"
	"time"

	"github.com/surge-proxy/surge-go/internal/protocol"
)

// ProxyResolver is a function that resolves a proxy name to a Dialer
type ProxyResolver func(name string) protocol.Dialer

// Group defines the interface for policy groups
type Group interface {
	protocol.Dialer

	// Proxies returns the list of proxy names in this group
	Proxies() []string

	// Now returns the currently selected proxy name
	Now() string
}

// UpdatableGroup is a group that supports updating its proxy list
type UpdatableGroup interface {
	Group
	UpdateProxies(proxies []string, localProxies map[string]protocol.Dialer)
}

// BaseGroup provides common fields for policy groups
type BaseGroup struct {
	NameStr      string
	TypeStr      string
	ProxiesList  []string
	LocalProxies map[string]protocol.Dialer
	Resolver     ProxyResolver
	FilterRegex  *regexp.Regexp
}

func (g *BaseGroup) Name() string {
	return g.NameStr
}

func (g *BaseGroup) Type() string {
	return g.TypeStr
}

// Proxies returns the list of proxy names in this group
func (g *BaseGroup) Proxies() []string {
	return g.ProxiesList
}

// SetFilter compiles and sets the regex filter
func (g *BaseGroup) SetFilter(regex string) error {
	if regex == "" {
		g.FilterRegex = nil
		return nil
	}
	re, err := regexp.Compile(regex)
	if err != nil {
		return err
	}
	g.FilterRegex = re
	return nil
}

// FilterProxies filters the list based on the regex if present
func (g *BaseGroup) FilterProxies(proxies []string) []string {
	if g.FilterRegex == nil {
		return proxies
	}
	var filtered []string
	for _, p := range proxies {
		if g.FilterRegex.MatchString(p) {
			filtered = append(filtered, p)
		}
	}
	return filtered
}

func (g *BaseGroup) Close() error {
	return nil
}

// SafeDial calls DialContext on keywords like "DIRECT" or "REJECT", or resolves child proxy
func (g *BaseGroup) SafeDial(ctx context.Context, network, address, childName string) (net.Conn, error) {
	if childName == "DIRECT" {
		// Use a temporary Direct dialer or we should have a global one.
		// For now simple net.Dialer
		// But ideally we resolve "DIRECT" from the resolver if it's there.
		// If resolver returns nil, we fallback.
		d := &net.Dialer{Timeout: 30 * time.Second}
		return d.DialContext(ctx, network, address)
	}
	if childName == "REJECT" {
		return nil, fmt.Errorf("connection rejected")
	}

	// Check local proxies first
	if g.LocalProxies != nil {
		if child, ok := g.LocalProxies[childName]; ok {
			return child.DialContext(ctx, network, address)
		}
	}

	if g.Resolver == nil {
		return nil, fmt.Errorf("proxy resolver is nil")
	}

	child := g.Resolver(childName)
	if child == nil {
		return nil, fmt.Errorf("proxy '%s' not found", childName)
	}

	return child.DialContext(ctx, network, address)
}

func (g *BaseGroup) Test(url string, timeout time.Duration) (int, error) {
	return 0, nil // Groups themselves usually don't have latency, unless we test the selected one?
}
