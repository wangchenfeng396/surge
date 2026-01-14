package policy

import (
	"context"
	"fmt"
	"math"
	"net"
	"sync"
	"time"

	"github.com/surge-proxy/surge-go/internal/protocol"
)

// URLTestGroup implements auto-testing policy group
type URLTestGroup struct {
	BaseGroup
	URL       string
	Interval  time.Duration
	Tolerance int // Tolerance in Ms

	current  string // The winner
	mu       sync.RWMutex
	stopChan chan struct{}
}

func (g *URLTestGroup) UpdateProxies(proxies []string, localProxies map[string]protocol.Dialer) {
	g.mu.Lock()

	// Apply filter
	proxies = g.FilterProxies(proxies)

	g.ProxiesList = proxies
	g.LocalProxies = localProxies

	// Reset current logic similar to SelectGroup
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
	g.mu.Unlock()

	// Trigger retest?
	go g.Retest()
}

// NewURLTestGroup creates a new URLTestGroup
func NewURLTestGroup(name string, proxies []string, resolver ProxyResolver, url string, interval int, tolerance int) *URLTestGroup {
	g := &URLTestGroup{
		BaseGroup: BaseGroup{
			NameStr:     name,
			TypeStr:     "url-test",
			ProxiesList: proxies,
			Resolver:    resolver,
		},
		URL:       url,
		Interval:  time.Duration(interval) * time.Second,
		Tolerance: tolerance,
		stopChan:  make(chan struct{}),
	}

	if len(proxies) > 0 {
		g.current = proxies[0]
	}

	// Start testing loop
	if interval > 0 {
		go g.startLoop()
	}

	return g
}

func (g *URLTestGroup) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	g.mu.RLock()
	target := g.current
	g.mu.RUnlock()

	if target == "" {
		return nil, fmt.Errorf("no proxy available in group %s", g.Name())
	}

	return g.SafeDial(ctx, network, address, target)
}

func (g *URLTestGroup) Now() string {
	g.mu.RLock()
	defer g.mu.RUnlock()
	return g.current
}

func (g *URLTestGroup) startLoop() {
	ticker := time.NewTicker(g.Interval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			g.Retest()
		case <-g.stopChan:
			return
		}
	}
}

// Retest performs latency test for all proxies and picks winner
func (g *URLTestGroup) Retest() {
	if g.Resolver == nil {
		return
	}

	type result struct {
		name    string
		latency int
		err     error
	}

	results := make(chan result, len(g.ProxiesList))
	var wg sync.WaitGroup

	for _, name := range g.ProxiesList {
		wg.Add(1)
		go func(n string) {
			defer wg.Done()
			p := g.Resolver(n)
			if p == nil {
				results <- result{name: n, err: fmt.Errorf("not found")}
				return
			}

			// Use a shorter timeout for testing
			lat, err := p.Test(g.URL, 5*time.Second)
			results <- result{name: n, latency: lat, err: err}
		}(name)
	}

	wg.Wait()
	close(results)

	bestName := ""
	bestLat := math.MaxInt32

	// Keep current choice if difference is within tolerance?
	// Surge logic: if current is still valid and not much slower than new best, keep it to avoid flapping.

	proxyMap := make(map[string]int)

	for res := range results {
		if res.err == nil {
			proxyMap[res.name] = res.latency
			if res.latency < bestLat {
				bestLat = res.latency
				bestName = res.name
			}
		}
	}

	if bestName != "" {
		g.mu.Lock()
		defer g.mu.Unlock()

		// Tolerance check
		if g.current != "" && g.current != bestName {
			if curLat, ok := proxyMap[g.current]; ok {
				// If current is valid, check if new best is significantly better
				if bestLat > curLat-g.Tolerance {
					// New best is not significantly better (latency diff < tolerance), keep current
					// e.g. best=100, cur=120, tol=50. 100 > 120-50 (70). True. Keep current.
					// e.g. best=50, cur=120, tol=50. 50 > 120-50 (70). False. Switch.
					return
				}
			}
		}

		g.current = bestName
	}
}

func (g *URLTestGroup) Close() error {
	close(g.stopChan)
	return nil
}
