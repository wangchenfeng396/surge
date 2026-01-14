package dns

import (
	"context"
	"errors"
	"fmt"
	"net"
	"strings"
	"time"

	"github.com/miekg/dns"
)

// SimpleResolver implements a resolver that queries specific upstream servers
type SimpleResolver struct {
	config  *Config
	clients []*dns.Client
}

// NewSimpleResolver creates a new SimpleResolver
func NewSimpleResolver(config *Config) *SimpleResolver {
	if config.Timeout == 0 {
		config.Timeout = 5 * time.Second
	}
	// Normalize servers
	for i, s := range config.Servers {
		if !strings.Contains(s, ":") {
			config.Servers[i] = s + ":53"
		}
	}

	return &SimpleResolver{
		config: config,
	}
}

// LookupIP queries upstreams for A and AAAA records
func (r *SimpleResolver) LookupIP(ctx context.Context, host string) ([]net.IP, error) {
	// Append dot if not present to make it FQDN
	if !strings.HasSuffix(host, ".") {
		host = host + "."
	}

	for _, server := range r.config.Servers {
		res, err := r.query(ctx, server, host)
		if err == nil && len(res) > 0 {
			return res, nil
		}
	}

	return nil, fmt.Errorf("lookup failed for %s", host)
}

// Test checks latency of all configured servers
func (r *SimpleResolver) Test(ctx context.Context) (map[string]int, error) {
	results := make(map[string]int)

	// Test each server
	for _, server := range r.config.Servers {
		start := time.Now()
		// Query root or google for check
		_, err := r.query(ctx, server, "google.com.")
		latency := int(time.Since(start).Milliseconds())

		if err != nil {
			results[server] = -1 // Error indicator
		} else {
			results[server] = latency
		}
	}
	return results, nil
}

func (r *SimpleResolver) query(ctx context.Context, server, host string) ([]net.IP, error) {
	c := new(dns.Client)
	c.Timeout = r.config.Timeout

	// Query A
	m := new(dns.Msg)
	m.SetQuestion(host, dns.TypeA)
	in, _, err := c.ExchangeContext(ctx, m, server)

	var ips []net.IP
	if err == nil && in != nil && in.Rcode == dns.RcodeSuccess {
		for _, ans := range in.Answer {
			if a, ok := ans.(*dns.A); ok {
				ips = append(ips, a.A)
			}
		}
	}

	// Query AAAA (optional, can be parallel)
	m6 := new(dns.Msg)
	m6.SetQuestion(host, dns.TypeAAAA)
	in6, _, err6 := c.ExchangeContext(ctx, m6, server)

	if err6 == nil && in6 != nil && in6.Rcode == dns.RcodeSuccess {
		for _, ans := range in6.Answer {
			if aaaa, ok := ans.(*dns.AAAA); ok {
				ips = append(ips, aaaa.AAAA)
			}
		}
	}

	if len(ips) == 0 {
		return nil, errors.New("no records found")
	}
	return ips, nil
}

func (r *SimpleResolver) Close() error {
	return nil
}
