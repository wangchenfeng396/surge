package protocol

import (
	"context"
	"io"
	"net"
	"net/http"
	"sync"
	"time"

	"github.com/surge-proxy/surge-go/internal/utils"
)

// DirectDialer implements Dialer interface for direct connections (no proxy)
type DirectDialer struct {
	name string
}

// NewDirectDialer creates a new DirectDialer
func NewDirectDialer(name string) *DirectDialer {
	if name == "" {
		name = "DIRECT"
	}
	return &DirectDialer{name: name}
}

// DialContext establishes a direct connection to the target address
func (d *DirectDialer) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	dialer := &net.Dialer{
		Timeout:   30 * time.Second,
		KeepAlive: 30 * time.Second,
	}
	network = utils.ResolveNetwork(network)
	return dialer.DialContext(ctx, network, address)
}

// Name returns the name of this dialer
func (d *DirectDialer) Name() string {
	return d.name
}

// Type returns the protocol type
func (d *DirectDialer) Type() string {
	return "direct"
}

// Test tests the latency by accessing the given URL directly
func (d *DirectDialer) Test(url string, timeout time.Duration) (int, error) {
	start := time.Now()

	client := &http.Client{
		Timeout: timeout,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}

	resp, err := client.Get(url)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	// Read and discard response body
	io.Copy(io.Discard, resp.Body)

	latency := time.Since(start).Milliseconds()
	return int(latency), nil
}

// Close closes the dialer (no-op for DirectDialer)
func (d *DirectDialer) Close() error {
	return nil
}

// RejectDialer moved to reject.go

// SimpleConnectionManager is a basic implementation of ConnectionManager
// It does not implement connection pooling (future optimization)
type SimpleConnectionManager struct {
	mu    sync.RWMutex
	stats ConnectionStats
}

// NewSimpleConnectionManager creates a new SimpleConnectionManager
func NewSimpleConnectionManager() *SimpleConnectionManager {
	return &SimpleConnectionManager{}
}

// Get creates a new connection (no pooling in this simple implementation)
func (m *SimpleConnectionManager) Get(ctx context.Context, dialer Dialer, network, address string) (net.Conn, error) {
	conn, err := dialer.DialContext(ctx, network, address)
	if err != nil {
		return nil, err
	}

	m.mu.Lock()
	m.stats.Active++
	m.stats.TotalOpened++
	m.mu.Unlock()

	return &trackedConn{
		Conn:    conn,
		manager: m,
	}, nil
}

// Put is a no-op in this simple implementation (no connection pooling)
func (m *SimpleConnectionManager) Put(dialer Dialer, conn net.Conn) error {
	return conn.Close()
}

// Close closes the manager
func (m *SimpleConnectionManager) Close() error {
	return nil
}

// Stats returns connection statistics
func (m *SimpleConnectionManager) Stats() *ConnectionStats {
	m.mu.RLock()
	defer m.mu.RUnlock()

	stats := m.stats
	return &stats
}

func (m *SimpleConnectionManager) onConnectionClosed() {
	m.mu.Lock()
	m.stats.Active--
	m.stats.TotalClosed++
	m.mu.Unlock()
}

// trackedConn wraps a net.Conn to track statistics
type trackedConn struct {
	net.Conn
	manager *SimpleConnectionManager
	closed  bool
	mu      sync.Mutex
}

// Close closes the connection and updates statistics
func (c *trackedConn) Close() error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.closed {
		return nil
	}

	c.closed = true
	c.manager.onConnectionClosed()
	return c.Conn.Close()
}

// SimpleTester implements basic latency testing
type SimpleTester struct {
	timeout time.Duration
}

// NewSimpleTester creates a new SimpleTester
func NewSimpleTester(timeout time.Duration) *SimpleTester {
	if timeout == 0 {
		timeout = 10 * time.Second
	}
	return &SimpleTester{timeout: timeout}
}

// Test tests a single proxy
func (t *SimpleTester) Test(ctx context.Context, dialer Dialer, url string) *TestResult {
	result := &TestResult{
		ProxyName: dialer.Name(),
		Timestamp: time.Now(),
	}

	latency, err := dialer.Test(url, t.timeout)
	if err != nil {
		result.Error = err
		return result
	}

	result.Latency = time.Duration(latency) * time.Millisecond
	return result
}

// TestMultiple tests multiple proxies concurrently
func (t *SimpleTester) TestMultiple(ctx context.Context, dialers []Dialer, url string) []*TestResult {
	results := make([]*TestResult, len(dialers))
	var wg sync.WaitGroup

	for i, dialer := range dialers {
		wg.Add(1)
		go func(idx int, d Dialer) {
			defer wg.Done()
			results[idx] = t.Test(ctx, d, url)
		}(i, dialer)
	}

	wg.Wait()
	return results
}
