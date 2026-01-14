package dns

import (
	"context"
	"fmt"
	"net"
	"strings"
)

// Manager coordinates DNS resolution
type Manager struct {
	hosts        *HostsResolver
	upstream     Resolver // SimpleResolver or DoH
	system       Resolver // DefaultResolver
	cache        *Cache
	alwaysRealIP map[string]bool
}

// NewManager creates a new DNS manager
func NewManager(hosts map[string]string, upstreamServers []string, dohURLs []string, alwaysRealIP []string) *Manager {
	mgr := &Manager{
		hosts:        NewHostsResolver(hosts),
		system:       NewDefaultResolver(),
		cache:        NewCache(0), // Default TTL
		alwaysRealIP: make(map[string]bool),
	}

	for _, host := range alwaysRealIP {
		mgr.alwaysRealIP[strings.ToLower(host)] = true
	}

	if len(dohURLs) > 0 {
		mgr.upstream = NewDoHResolver(dohURLs)
	} else if len(upstreamServers) > 0 {
		mgr.upstream = NewSimpleResolver(&Config{
			Servers: upstreamServers,
		})
	}

	return mgr
}

// IsAlwaysRealIP checks if a host should avoid FakeIP
func (m *Manager) IsAlwaysRealIP(host string) bool {
	host = strings.ToLower(Canonicalize(host))
	// exact match
	if m.alwaysRealIP[host] {
		return true
	}
	// suffix match logic? standard config usually is just exact or suffix?
	// Surge 'always-real-ip' acts on "domains".
	// Let's support suffix matching if starts with '.'? Or just exact?
	// Surge doc: "The domains should be resolved to real IP".
	// Usually suffix.
	for domain := range m.alwaysRealIP {
		if strings.HasSuffix(host, domain) {
			// check boundary? .google.com matches mail.google.com
			if len(host) == len(domain) || (len(host) > len(domain) && host[len(host)-len(domain)-1] == '.') {
				return true
			}
		}
	}
	return false
}

// LookupIP resolves IP for host using the chain: Hosts -> Cache -> Upstream -> System
func (m *Manager) LookupIP(ctx context.Context, host string) ([]net.IP, error) {
	// 1. Check Hosts (fastest, static)
	host = Canonicalize(host)
	if ips, err := m.hosts.LookupIP(ctx, host); err == nil {
		return ips, nil
	}

	// 2. Check Cache
	if ips := m.cache.Get(host); ips != nil {
		return ips, nil
	}

	var ips []net.IP
	var err error

	// 3. Check Upstream if configured
	if m.upstream != nil {
		ips, err = m.upstream.LookupIP(ctx, host)
		if err == nil {
			m.cache.Set(host, ips)
			return ips, nil
		}
		// If upstream fails, fall through to system?
		// Usually if upstream is configured, we might NOT want system fallback to avoid leak.
		// Use a policy flag? For now, mimicking previous logic: error if upstream fails.
		return nil, fmt.Errorf("lookup failed on upstream: %v", err)
	}

	// 4. Fallback to System
	ips, err = m.system.LookupIP(ctx, host)
	if err == nil {
		m.cache.Set(host, ips)
	}
	return ips, err
}

// TestUpstreams tests all configured upstream resolvers
func (m *Manager) TestUpstreams(ctx context.Context) map[string]int {
	results := make(map[string]int)

	// Test Upstream
	if m.upstream != nil {
		if res, err := m.upstream.Test(ctx); err == nil {
			for k, v := range res {
				results[k] = v
			}
		}
	}

	// Only test system if no upstream or just to report system status?
	// Usually users care about their manually configured DNS.
	// But let's include system for completeness if upstream is not exclusive.
	// Actually, just always test system too if needed?
	// User screenshot shows many "Answer from...".
	// Let's rely on upstream results primarily.

	return results
}

// Canonicalize ensures host is normalized
func Canonicalize(host string) string {
	if len(host) > 0 && host[len(host)-1] == '.' {
		return host[:len(host)-1]
	}
	return host
}

func (m *Manager) Close() error {
	if m.upstream != nil {
		m.upstream.Close()
	}
	m.hosts.Close()
	m.system.Close()
	return nil
}
