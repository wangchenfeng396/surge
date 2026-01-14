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

// SmartGroup implements a smart selection policy
type SmartGroup struct {
	BaseGroup
	URL      string
	Interval time.Duration

	current  string
	stats    map[string]*proxyStats
	mu       sync.RWMutex
	stopChan chan struct{}
}

func (g *SmartGroup) UpdateProxies(proxies []string, localProxies map[string]protocol.Dialer) {
	g.mu.Lock()
	g.ProxiesList = proxies
	g.LocalProxies = localProxies

	// Init stats for new proxies
	for _, p := range proxies {
		if _, ok := g.stats[p]; !ok {
			g.stats[p] = &proxyStats{LatencyMs: 9999}
		}
	}
	// Cleanup old stats? Optional.

	// Reset current
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

	go g.Retest()
}

type proxyStats struct {
	LatencyMs    int
	FailureCount int
	LastUpdate   time.Time
}

// NewSmartGroup creates a new SmartGroup
func NewSmartGroup(name string, proxies []string, resolver ProxyResolver, url string, interval int, evaluateBeforeUse bool) *SmartGroup {
	g := &SmartGroup{
		BaseGroup: BaseGroup{
			NameStr:     name,
			TypeStr:     "smart",
			ProxiesList: proxies,
			Resolver:    resolver,
		},
		URL:      url,
		Interval: time.Duration(interval) * time.Second,
		stats:    make(map[string]*proxyStats),
		stopChan: make(chan struct{}),
	}

	// Initialize stats
	for _, p := range proxies {
		g.stats[p] = &proxyStats{LatencyMs: 9999}
	}

	if len(proxies) > 0 {
		if !evaluateBeforeUse {
			g.current = proxies[0]
		}
	}

	if interval > 0 {
		go g.startLoop()
	}

	// If evaluateBeforeUse is true, we should trigger a test immediately
	if evaluateBeforeUse {
		// We do this asynchronously to avoid blocking startup,
		// but g.current is empty so requests will fail until test completes?
		// Or should we block? The UI says "first request to also wait".
		// To implement that strictly, DialContext needs to wait.
		// For now, let's just trigger retest.
		go g.Retest()
	}

	return g
}

func (g *SmartGroup) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	g.mu.RLock()
	target := g.current
	g.mu.RUnlock()

	if target == "" {
		return nil, fmt.Errorf("no proxy available in group %s", g.Name())
	}

	conn, err := g.SafeDial(ctx, network, address, target)

	// Smart logic: verify connection success/fail
	g.updateStats(target, err)

	return conn, err
}

func (g *SmartGroup) updateStats(name string, err error) {
	g.mu.Lock()
	defer g.mu.Unlock()

	stat, ok := g.stats[name]
	if !ok {
		return
	}

	if err != nil {
		stat.FailureCount++
	} else {
		// Decay failure count on success
		if stat.FailureCount > 0 {
			stat.FailureCount--
		}
	}

	// Trigger re-evaluation if current failed?
	if err != nil && name == g.current {
		go g.evaluate() // Run in background to avoid blocking Dial
	}
}

func (g *SmartGroup) Now() string {
	g.mu.RLock()
	defer g.mu.RUnlock()
	return g.current
}

func (g *SmartGroup) startLoop() {
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

func (g *SmartGroup) Retest() {
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
				return
			}
			lat, err := p.Test(g.URL, 5*time.Second)
			results <- result{name: n, latency: lat, err: err}
		}(name)
	}

	wg.Wait()
	close(results)

	g.mu.Lock()
	for res := range results {
		if stat, ok := g.stats[res.name]; ok {
			if res.err == nil {
				stat.LatencyMs = res.latency
			} else {
				// Test failed, treat as failure
				stat.FailureCount++
				stat.LatencyMs = 9999
			}
			stat.LastUpdate = time.Now()
		}
	}
	g.mu.Unlock()

	g.evaluate()
}

// evaluate picks the best proxy based on score
func (g *SmartGroup) evaluate() {
	g.mu.Lock()
	defer g.mu.Unlock()

	bestName := ""
	bestScore := math.MaxInt64

	for name, stat := range g.stats {
		// Score = Latency + (FailureCount * 2000)
		score := stat.LatencyMs + (stat.FailureCount * 2000)

		if score < bestScore {
			bestScore = score
			bestName = name
		}
	}

	if bestName != "" {
		g.current = bestName
	}
}

func (g *SmartGroup) Close() error {
	close(g.stopChan)
	return nil
}
