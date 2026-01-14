package dns

import (
	"context"
	"net"
	"time"
)

// Resolver defines the interface for DNS resolution
type Resolver interface {
	// LookupIP returns the IP addresses for the given host
	LookupIP(ctx context.Context, host string) ([]net.IP, error)

	// Test checks latency of upstream servers
	Test(ctx context.Context) (map[string]int, error)

	// Close releases any resources
	Close() error
}

// Config defines DNS configuration
type Config struct {
	Servers []string // DNS servers (e.g. "8.8.8.8:53", "1.1.1.1:53")
	Timeout time.Duration
}

// DefaultResolver uses the system resolver
type DefaultResolver struct {
	resolver *net.Resolver
}

func NewDefaultResolver() *DefaultResolver {
	return &DefaultResolver{
		resolver: &net.Resolver{},
	}
}

func (r *DefaultResolver) LookupIP(ctx context.Context, host string) ([]net.IP, error) {
	return r.resolver.LookupIP(ctx, "ip", host)
}

func (r *DefaultResolver) Test(ctx context.Context) (map[string]int, error) {
	start := time.Now()
	_, err := r.LookupIP(ctx, "google.com")
	latency := int(time.Since(start).Milliseconds())
	if err != nil {
		return map[string]int{"System": -1}, err
	}
	return map[string]int{"System": latency}, nil
}

func (r *DefaultResolver) Close() error {
	return nil
}
