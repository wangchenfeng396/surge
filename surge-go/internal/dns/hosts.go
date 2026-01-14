package dns

import (
	"context"
	"errors"
	"net"
	"strings"
	"sync"
)

// HostsResolver implements static DNS mapping
type HostsResolver struct {
	hosts map[string]net.IP
	mu    sync.RWMutex
}

// NewHostsResolver creates a new HostsResolver
func NewHostsResolver(hosts map[string]string) *HostsResolver {
	parsed := make(map[string]net.IP)
	for domain, ipStr := range hosts {
		ip := net.ParseIP(ipStr)
		if ip != nil {
			parsed[strings.ToLower(domain)] = ip
		}
	}

	return &HostsResolver{
		hosts: parsed,
	}
}

// LookupIP satisfies Resolver interface
func (r *HostsResolver) LookupIP(ctx context.Context, host string) ([]net.IP, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	host = strings.ToLower(strings.TrimSuffix(host, "."))

	// 1. Try exact match
	if ip, ok := r.hosts[host]; ok {
		return []net.IP{ip}, nil
	}

	// 2. Try wildcard match
	// Iterate to find *.domain.com
	for domain, ip := range r.hosts {
		if strings.HasPrefix(domain, "*.") {
			suffix := domain[1:] // .example.com
			if strings.HasSuffix(host, suffix) {
				return []net.IP{ip}, nil
			}
		}
	}

	return nil, errors.New("host not found in static mappings")
}

func (r *HostsResolver) Close() error {
	return nil
}
