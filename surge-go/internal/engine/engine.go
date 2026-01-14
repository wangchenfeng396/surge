package engine

import (
	"context"
	"fmt"
	"io"
	"net"
	"net/url"
	"strconv"
	"sync"
	"time"

	"log"

	"github.com/surge-proxy/surge-go/internal/capture"
	"github.com/surge-proxy/surge-go/internal/config"
	"github.com/surge-proxy/surge-go/internal/dns"
	"github.com/surge-proxy/surge-go/internal/mitm"
	"github.com/surge-proxy/surge-go/internal/policy"
	"github.com/surge-proxy/surge-go/internal/protocol"
	"github.com/surge-proxy/surge-go/internal/rewrite"
	"github.com/surge-proxy/surge-go/internal/rule"
	"github.com/surge-proxy/surge-go/internal/stats"
	"github.com/surge-proxy/surge-go/internal/tracker"
	// "github.com/surge-proxy/surge-go/internal/tun"
)

// Engine is the central controller for the proxy system
type Engine struct {
	mu sync.RWMutex

	Config       *config.SurgeConfig
	Stats        *stats.Collector
	DNSManager   *dns.Manager
	RuleEngine   *rule.Engine
	URLRewriter  *rewrite.URLRewriter
	BodyRewriter *rewrite.BodyRewriter
	MITMManager  *mitm.Manager

	// Proxies and Groups
	Proxies map[string]protocol.Dialer
	Groups  map[string]policy.Group

	// Runtime state
	running      bool
	Mode         string
	Tracker      *tracker.Tracker
	CaptureStore *capture.Store
	// TUNDevice    *tun.Device

	// Test state
	// Test state
	// currentGlobalProxy string     // Used by legacy test
	// testMutex          sync.Mutex // Used by legacy test
}

// NewEngine creates a new engine instance
func NewEngine(cfg *config.SurgeConfig) *Engine {
	e := &Engine{
		Config:       cfg,
		Stats:        stats.NewCollector(),
		Proxies:      make(map[string]protocol.Dialer),
		Groups:       make(map[string]policy.Group),
		Mode:         "rule",
		CaptureStore: capture.NewStore(1000),
	}
	e.Tracker = tracker.NewTracker(e.CaptureStore)
	return e
}

// Start initializes and starts all components
func (e *Engine) Start() error {
	e.mu.Lock()
	defer e.mu.Unlock()

	if e.running {
		return nil
	}

	// 1. Load Proxies
	if err := e.loadProxies(e.Config); err != nil {
		return fmt.Errorf("failed to load proxies: %v", err)
	}

	// 2. Load Groups
	if err := e.loadGroups(e.Config); err != nil {
		return fmt.Errorf("failed to load groups: %v", err)
	}

	// 3. Initialize DNS Manager
	hostsMap := make(map[string]string)
	for _, h := range e.Config.Hosts {
		hostsMap[h.Domain] = h.Value
	}

	e.DNSManager = dns.NewManager(
		hostsMap,
		e.Config.General.DNSServer,
		e.Config.General.EncryptedDNSServer,
		e.Config.General.AlwaysRealIP,
	)

	// 4. Initialize Rewriters & MITM
	var err error
	if e.URLRewriter, err = rewrite.NewURLRewriter(e.Config.URLRewrites); err != nil {
		return fmt.Errorf("failed to init url rewriter: %v", err)
	}
	if e.BodyRewriter, err = rewrite.NewBodyRewriter(e.Config.BodyRewrites); err != nil {
		return fmt.Errorf("failed to init body rewriter: %v", err)
	}
	if e.MITMManager, err = mitm.NewManager(e.Config.MITM); err != nil {
		return fmt.Errorf("failed to init mitm manager: %v", err)
	}

	// 5. Initialize Rule Engine
	e.RuleEngine = rule.NewEngine()
	if err := e.loadRules(); err != nil {
		return fmt.Errorf("failed to load rules: %v", err)
	}

	// 6. Start Servers
	// Listeners are managed by main.go or caller

	e.running = true
	return nil
}

func (e *Engine) loadRules() error {
	return e.RuleEngine.LoadRulesFromConfigs(e.Config.Rules)
}

// Stop stops all components
func (e *Engine) Stop() error {
	e.mu.Lock()
	defer e.mu.Unlock()

	if !e.running {
		return nil
	}

	// Close proxies/groups if needed
	for _, p := range e.Proxies {
		p.Close()
	}
	// Groups usually don't need close but URLTest might have routines
	for _, g := range e.Groups {
		if c, ok := g.(io.Closer); ok {
			c.Close()
		}
	}

	e.running = false
	return nil
}

// Shutdown gracefully stops the engine
func (e *Engine) Shutdown(ctx context.Context) error {
	// Stop components
	e.Stop()

	// Wait/Cleanup logic if any (e.g. stats saving)
	// TODO: Save stats

	return nil
}

// SetMode sets the proxy mode
func (e *Engine) SetMode(mode string) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.Mode = mode
}

// GetMode returns the current proxy mode
func (e *Engine) GetMode() string {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.Mode
}

// HandleRequest implements server.RequestHandler
func (e *Engine) HandleRequest(ctx context.Context, network, address, source string) protocol.Dialer {
	// Check for forced proxy in context (for testing)
	if v := ctx.Value("TestProxyName"); v != nil {
		if name, ok := v.(string); ok && name != "" {
			log.Printf("Engine: Force proxy %s from context", name)
			if p := e.getAdapter(name); p != nil {
				log.Printf("Engine: Found adapter for %s: %T", name, p)
				return p
			}
			log.Printf("Engine: Adapter %s not found", name)
		}
	}

	// Rewrite URL
	if e.URLRewriter != nil {
		// Need to parse address to get URL?
		// address is host:port. Not full URL if it's CONNECT/SOCKS.
		// But for HTTP proxy/transparent, we might not have full URL here?
		// Wait, HandleRequest is called by SOCKS/HTTP server.
		// The 'address' is the target.
		// If it's HTTP proxy, we might have full URL in context or need to verify how server passes it.
		// Current signature: HandleRequest(ctx, network, address, source)
		// address = "google.com:443" or "www.google.com:80".
		// URL Rewrites typically work on HTTP requests.
		// If this is a TCP tunnel (CONNECT), we only have host:port.
		// SURGE URL Rewrite works on HTTP request URL.
		// We probably need to construct a URL or this rewriting happens at a higher layer (like HTTP handler)?
		// But Engine is the handler.
		// Let's assume for now we construct "http://" + address for checking if network is tcp?
		// Or better: Rewrite applies to HTTP requests ONLY.
		// CONNECT is a tunnel. Rewrites (302) on connect?
		// Surge supports "URL Rewrite" for HTTP methods.
		// Handling this here might clearly apply to CONNECT too if regex matches.
		// But we need the Path. Address usually doesn't have path for CONNECT.
		// Address has path for HTTP Proxy standard request?
		// Checking server implementation: server/http.go
		// CONNECT: address = host:port
		// GET/POST: address = host:port (constructed from URL)

		// If we want FULL URL rewrite, we need the full URL passed to HandleRequest or access to it.
		// But let's look at `internal/rewrite/url.go`: It takes `urlStr string`.

		// LIMITATION: Currently HandleRequest only gets target address.
		// Rewrites usually need Path.
		// We might be able to implement basic Host rewrite here, but for Path rewrite we need full URL.

		// Assuming we implement logic here, but acknowledging limitation.
		// Let's defer actual implementation until we check server/http.go to see if we can pass full URL.
	}
	e.mu.RLock()
	mode := e.Mode
	e.mu.RUnlock()

	var selectedDialer protocol.Dialer
	var policyName string
	var ruleDesc string

	// Mode handling
	switch mode {
	case "direct":
		selectedDialer = protocol.NewDirectDialer("DIRECT")
		policyName = "DIRECT"
		ruleDesc = "Mode: Direct"
	case "global":
		// Try "Proxy" group, then "Global" group, then fallback to DIRECT
		if p := e.getAdapter("Proxy"); p != nil {
			selectedDialer = p
			policyName = "Proxy"
		} else if p := e.getAdapter("Global"); p != nil {
			selectedDialer = p
			policyName = "Global"
		} else {
			selectedDialer = protocol.NewDirectDialer("DIRECT")
			policyName = "DIRECT"
		}

		ruleDesc = "Mode: Global"
	default:
		// Rule handling (mode == "rule" or unknown)
		// Address is "host:port".
		host, portStr, _ := net.SplitHostPort(address)
		port, _ := strconv.Atoi(portStr)

		meta := &rule.RequestMetadata{
			Type: network,
			Host: host,
			Port: port,
		}
		if source != "" {
			if ip := net.ParseIP(source); ip != nil {
				meta.SourceIP = ip
			} else {
				// Handle host:port source format if needed
				h, _, err := net.SplitHostPort(source)
				if err == nil {
					meta.SourceIP = net.ParseIP(h)
				}
			}
		}

		// Match
		if e.RuleEngine != nil {
			adapter, matchedRule := e.RuleEngine.Match(meta)
			if adapter != "" {
				selectedDialer = e.getAdapter(adapter)
				policyName = adapter
				if matchedRule != nil {
					ruleDesc = fmt.Sprintf("%s, %s", matchedRule.Type(), matchedRule.Payload())
				} else {
					ruleDesc = "Unknown Rule"
				}
			}
		}

		// Default to DIRECT
		if selectedDialer == nil {
			selectedDialer = protocol.NewDirectDialer("DIRECT")
			policyName = "DIRECT"
			ruleDesc = "FINAL"
		}
	}

	// Prepare tracking metadata
	// Try to resolve PID/Process if possible (requires advanced platform specific code, skipping for now)

	connMeta := &tracker.Connection{
		SourceIP:      source,
		TargetAddress: address,
		Rule:          ruleDesc,
		Policy:        policyName,
	}

	return &tracker.TrackingDialer{
		Dialer:  selectedDialer,
		Tracker: e.Tracker,
		Meta:    connMeta,
	}
}

func (e *Engine) getAdapter(name string) protocol.Dialer {
	if name == "DIRECT" {
		return protocol.NewDirectDialer("DIRECT")
	}
	if name == "REJECT" {
		return protocol.NewRejectDialer("REJECT")
	}
	if name == "REJECT-NO-DROP" {
		return protocol.NewRejectNoDropDialer()
	}
	if name == "REJECT-DROP" {
		return protocol.NewRejectDropDialer()
	}
	if name == "REJECT-TINYGIF" {
		return protocol.NewRejectTinyGifDialer()
	}

	e.mu.RLock()
	defer e.mu.RUnlock()

	if p, ok := e.Proxies[name]; ok {
		return p
	}
	if g, ok := e.Groups[name]; ok {
		return g
	}

	return protocol.NewDirectDialer("DIRECT")
}

// GetStats returns current stats
func (e *Engine) GetStats() interface{} {
	// Wrapper capability usually returns struct, here we return map or struct from Collector
	// Assuming Collector has GetStats
	return e.Stats.GetStats()
}

// GetProxyList returns list of proxies with status
func (e *Engine) GetProxyList() interface{} {
	e.mu.RLock()
	defer e.mu.RUnlock()

	var list []map[string]interface{}

	// Collect from Groups (which contain both manual proxies and decision logic)
	for name, group := range e.Groups {
		item := map[string]interface{}{
			"name": name,
			"type": group.Type(),
		}

		if sg, ok := group.(*policy.SelectGroup); ok {
			item["now"] = sg.Now()
		} else if ug, ok := group.(*policy.URLTestGroup); ok {
			item["now"] = ug.Now()
		}

		list = append(list, item)
	}

	return list
}

// ResolveDNS resolves a host to IPs
func (e *Engine) ResolveDNS(host string) ([]string, error) {
	if e.DNSManager == nil {
		return nil, fmt.Errorf("DNS manager not initialized")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	ips, err := e.DNSManager.LookupIP(ctx, host)
	if err != nil {
		return nil, err
	}

	var result []string
	for _, ip := range ips {
		result = append(result, ip.String())
	}
	return result, nil
}

// MatchRule matches a rule for a given request
func (e *Engine) MatchRule(reqURL, sourceIP, process string) (string, string, error) {
	if e.RuleEngine == nil {
		return "", "", fmt.Errorf("Rule engine not initialized")
	}

	u, err := url.Parse(reqURL)
	if err != nil {
		return "", "", fmt.Errorf("invalid URL: %v", err)
	}

	port := 80
	if u.Scheme == "https" {
		port = 443
	}
	host := u.Hostname()
	if h, p, err := net.SplitHostPort(u.Host); err == nil {
		host = h
		if pi, err := strconv.Atoi(p); err == nil {
			port = pi
		}
	}

	meta := &rule.RequestMetadata{
		Type:        "tcp", // Default assumptions
		Host:        host,
		Port:        port,
		ProcessPath: process,
	}

	// Parse Host as IP if possible
	if ip := net.ParseIP(host); ip != nil {
		meta.IP = ip
	}

	if sourceIP != "" {
		if ip := net.ParseIP(sourceIP); ip != nil {
			meta.SourceIP = ip
		}
	}

	adapter, matchedRule := e.RuleEngine.Match(meta)
	ruleDesc := "FINAL"
	if matchedRule != nil {
		ruleDesc = fmt.Sprintf("%s, %s", matchedRule.Type(), matchedRule.Payload())
	}

	return adapter, ruleDesc, nil
}

// Reload applies a new configuration
func (e *Engine) Reload(cfg *config.SurgeConfig) error {
	e.mu.Lock()
	defer e.mu.Unlock()

	e.Stop()
	e.Config = cfg
	return e.Start()
}

// EnableTUN enables TUN mode
func (e *Engine) EnableTUN() error {
	// e.mu.Lock()
	// defer e.mu.Unlock()

	// if e.TUNDevice != nil {
	// 	return nil // Already enabled
	// }

	// Start TUN
	// dev, err := tun.Start("utun", "198.18.0.1", e)
	// if err != nil {
	// 	return err
	// }
	// e.TUNDevice = dev
	return fmt.Errorf("TUN mode implementation disabled due to gVisor build issues")
}

// DisableTUN disables TUN mode
func (e *Engine) DisableTUN() error {
	// TODO: Implement TUN
	return nil
}

// IsTUNEnabled checks if TUN is enabled
func (e *Engine) IsTUNEnabled() bool {
	return false
}

// TestProxy tests the latency of a proxy or group
func (e *Engine) TestProxy(name, testURL string) (int, error) {
	if testURL == "" {
		testURL = "http://connect.rom.miui.com/generate_204"
	}

	e.mu.RLock()
	var dialer protocol.Dialer
	if name == "DIRECT" {
		dialer = protocol.NewDirectDialer("DIRECT")
	} else if p, ok := e.Proxies[name]; ok {
		dialer = p
	} else if g, ok := e.Groups[name]; ok {
		dialer = g
	}
	e.mu.RUnlock()

	if dialer == nil {
		return 0, fmt.Errorf("proxy or group not found: %s", name)
	}

	return dialer.Test(testURL, 10*time.Second)
}

// TestProxyDetailed tests the latency of a proxy and returns detailed metrics
func (e *Engine) TestProxyDetailed(name, testURL string) (map[string]int64, error) {
	if testURL == "" {
		testURL = "http://connect.rom.miui.com/generate_204"
	}

	e.mu.RLock()
	var dialer protocol.Dialer
	if name == "DIRECT" {
		dialer = protocol.NewDirectDialer("DIRECT")
	} else if p, ok := e.Proxies[name]; ok {
		dialer = p
	} else if g, ok := e.Groups[name]; ok {
		dialer = g
	}
	e.mu.RUnlock()

	if dialer == nil {
		return nil, fmt.Errorf("proxy or group not found: %s", name)
	}

	// Check if dialer supports detailed testing
	if tester, ok := dialer.(protocol.LatencyTester); ok {
		stats, err := tester.TestLatency(testURL, 10*time.Second)
		if err != nil {
			return nil, err
		}
		return map[string]int64{
			"tcp":       stats.TCPHandshake,
			"handshake": stats.Handshake,
			"total":     stats.Total,
		}, nil
	}

	// Fallback to standard test
	latency, err := dialer.Test(testURL, 10*time.Second)
	if err != nil {
		return nil, err
	}

	return map[string]int64{
		"total": int64(latency),
	}, nil
}

// SetGlobalProxy 临时设置全局代理（用于测试）- Deprecated
// func (e *Engine) SetGlobalProxy(proxyName string) error { ... }

// ClearGlobalProxy 清除临时全局代理 - Deprecated
// func (e *Engine) ClearGlobalProxy() { ... }

// LockTest 获取测试锁（用于并发控制）- Deprecated
// func (e *Engine) LockTest() { ... }

// UnlockTest 释放测试锁 - Deprecated
// func (e *Engine) UnlockTest() { ... }

// HandleTUNConnection implements tun.Handler
func (e *Engine) HandleTUNConnection(conn net.Conn, target string) {
	// Basic implementation: pass to HandleRequest
	// Need context
	ctx := context.Background()
	dialer := e.HandleRequest(ctx, "tcp", target, conn.RemoteAddr().String())

	// Dial target
	targetConn, err := dialer.DialContext(ctx, "tcp", target)
	if err != nil {
		conn.Close()
		return
	}

	// Relay
	// Reuse HTTP server relay logic? Or simple copy
	go func() {
		defer conn.Close()
		defer targetConn.Close()
		io.Copy(conn, targetConn)
	}()
	go func() {
		defer conn.Close()
		defer targetConn.Close()
		io.Copy(targetConn, conn)
	}()
}
