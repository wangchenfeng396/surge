package dns

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"time"

	"github.com/miekg/dns"
)

// DoHResolver implements DNS over HTTPS
type DoHResolver struct {
	urls   []string
	client *http.Client
}

// NewDoHResolver creates a new DoH resolver with multiple servers
func NewDoHResolver(urls []string) *DoHResolver {
	return &DoHResolver{
		urls: urls,
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// LookupIP queries DoH server for IP addresses
func (r *DoHResolver) LookupIP(ctx context.Context, host string) ([]net.IP, error) {
	// Try each URL
	var lastErr error
	for _, url := range r.urls {
		ips, err := r.query(ctx, url, host, dns.TypeA)
		if err == nil {
			return ips, nil
		}
		lastErr = err
	}
	// If no URLs or all failed
	if lastErr == nil {
		return nil, fmt.Errorf("no DoH servers available")
	}
	return nil, lastErr
}

// Test checks latency of all DoH URLs
func (r *DoHResolver) Test(ctx context.Context) (map[string]int, error) {
	results := make(map[string]int)

	for _, url := range r.urls {
		start := time.Now()
		// Perform a query
		_, err := r.query(ctx, url, "google.com.", dns.TypeA)
		latency := int(time.Since(start).Milliseconds())

		if err != nil {
			results[url] = -1
		} else {
			results[url] = latency
		}
	}
	return results, nil
}

func (r *DoHResolver) query(ctx context.Context, url, host string, qtype uint16) ([]net.IP, error) {
	if host == "" {
		return nil, fmt.Errorf("empty host")
	}
	if host[len(host)-1] != '.' {
		host = host + "."
	}

	m := new(dns.Msg)
	m.SetQuestion(host, qtype)

	packed, err := m.Pack()
	if err != nil {
		return nil, err
	}

	// POST method for DoH is preferred for larger queries,
	// GET with base64url is also supported. Let's use POST.
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(packed))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/dns-message")
	req.Header.Set("Accept", "application/dns-message")

	resp, err := r.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("DoH server returned status: %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	var in dns.Msg
	if err := in.Unpack(body); err != nil {
		return nil, err
	}

	var ips []net.IP
	if in.Rcode == dns.RcodeSuccess {
		for _, ans := range in.Answer {
			if qtype == dns.TypeA {
				if a, ok := ans.(*dns.A); ok {
					ips = append(ips, a.A)
				}
			} else if qtype == dns.TypeAAAA {
				if aaaa, ok := ans.(*dns.AAAA); ok {
					ips = append(ips, aaaa.AAAA)
				}
			}
		}
	}

	if len(ips) == 0 {
		return nil, fmt.Errorf("no records found")
	}
	return ips, nil
}

func (r *DoHResolver) Close() error {
	return nil
}
