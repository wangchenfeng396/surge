package protocol

import (
	"context"
	"errors"
	"fmt"
	"net"
	"strings"
	"time"
)

// Common errors
var (
	ErrInvalidConfig    = errors.New("invalid proxy configuration")
	ErrConnectionFailed = errors.New("connection failed")
	ErrTimeout          = errors.New("connection timeout")
	ErrAuthFailed       = errors.New("authentication failed")
)

// Dialer defines the unified interface for all proxy protocols
// All proxy implementations (VMess, Trojan, VLESS, etc.) must implement this interface
type Dialer interface {
	// DialContext establishes a connection to the target address through the proxy
	// network can be "tcp", "tcp4", "tcp6", "udp", "udp4", "udp6"
	// address is in the format "host:port"
	DialContext(ctx context.Context, network, address string) (net.Conn, error)

	// Name returns the name/tag of this proxy
	Name() string

	// Type returns the protocol type (vmess, trojan, vless, etc.)
	Type() string

	// Test tests the proxy latency by accessing the given URL
	// Returns latency in milliseconds, or error if test fails
	Test(url string, timeout time.Duration) (latency int, err error)

	// Close closes the dialer and releases resources (e.g., connection pools)
	Close() error
}

// LatencyStats contains detailed latency metrics
type LatencyStats struct {
	TCPHandshake int64 // Time to establish TCP connection to proxy server (ms)
	Handshake    int64 // Time for proxy handshake (Connect command) (ms)
	Total        int64 // Total time for HTTP RTT (ms)
}

// LatencyTester is an optional interface for Dialers that support detailed latency testing
type LatencyTester interface {
	TestLatency(url string, timeout time.Duration) (LatencyStats, error)
}

// ProxyInfo contains basic information about a proxy
type ProxyInfo struct {
	Name     string            // Proxy name
	Type     string            // Protocol type (vmess, trojan, vless, etc.)
	Server   string            // Server address
	Port     int               // Server port
	Options  map[string]string // Additional options
	Metadata map[string]string // User-defined metadata
}

// ProxyConfig is a generic proxy configuration
// Specific protocol implementations should parse this into their own config structs
type ProxyConfig struct {
	Name    string                 // Proxy name (must be unique)
	Type    string                 // Protocol type: vmess, trojan, vless, shadowsocks, etc.
	Server  string                 // Server address (IP or domain)
	Port    int                    // Server port
	Options map[string]interface{} // Protocol-specific options
}

// Validate validates the basic proxy configuration
func (c *ProxyConfig) Validate() error {
	if c.Name == "" {
		return errors.New("proxy name cannot be empty")
	}
	if c.Type == "" {
		return errors.New("proxy type cannot be empty")
	}
	if c.Server == "" {
		return errors.New("proxy server cannot be empty")
	}
	if c.Port <= 0 || c.Port > 65535 {
		return errors.New("invalid proxy port")
	}
	return nil
}

// GetString returns a string option value
func (c *ProxyConfig) GetString(key string) (string, bool) {
	if v, ok := c.Options[key]; ok {
		if s, ok := v.(string); ok {
			return s, true
		}
	}
	return "", false
}

// GetInt returns an int option value
func (c *ProxyConfig) GetInt(key string) (int, bool) {
	if v, ok := c.Options[key]; ok {
		switch val := v.(type) {
		case int:
			return val, true
		case int64:
			return int(val), true
		case float64:
			return int(val), true
		case string:
			var i int
			if _, err := fmt.Sscanf(val, "%d", &i); err == nil {
				return i, true
			}
		}
	}
	return 0, false
}

// GetBool returns a bool option value
func (c *ProxyConfig) GetBool(key string) (bool, bool) {
	if v, ok := c.Options[key]; ok {
		switch val := v.(type) {
		case bool:
			return val, true
		case string:
			return strings.ToLower(val) == "true" || val == "1" || strings.ToLower(val) == "on", true
		}
	}
	return false, false
}

// ConnectionManager manages proxy connections
type ConnectionManager interface {
	// Get retrieves a connection from the pool or creates a new one
	Get(ctx context.Context, dialer Dialer, network, address string) (net.Conn, error)

	// Put returns a connection to the pool for reuse
	Put(dialer Dialer, conn net.Conn) error

	// Close closes all connections and releases resources
	Close() error

	// Stats returns connection statistics
	Stats() *ConnectionStats
}

// ConnectionStats contains connection statistics
type ConnectionStats struct {
	Active      int   // Currently active connections
	Idle        int   // Idle connections in pool
	TotalOpened int64 // Total connections opened
	TotalClosed int64 // Total connections closed
	TotalReused int64 // Total connections reused from pool
}

// DialerFactory creates Dialer instances from ProxyConfig
type DialerFactory interface {
	// Create creates a new Dialer from the given configuration
	Create(config *ProxyConfig) (Dialer, error)

	// SupportedTypes returns a list of supported protocol types
	SupportedTypes() []string
}

// TestResult contains the result of a proxy test
type TestResult struct {
	ProxyName string        // Name of the tested proxy
	Latency   time.Duration // Latency (0 if failed)
	Error     error         // Error if test failed
	Timestamp time.Time     // When the test was performed
}

// Tester performs latency tests on proxies
type Tester interface {
	// Test tests a single proxy
	Test(ctx context.Context, dialer Dialer, url string) *TestResult

	// TestMultiple tests multiple proxies concurrently
	TestMultiple(ctx context.Context, dialers []Dialer, url string) []*TestResult
}

// ServerInfoProvider is an interface for getting proxy server information
// This allows us to get the server address from a Dialer for relay chains
type ServerInfoProvider interface {
	GetServerAddr() string // Returns "server:port"
}

// TunnelDialer is an interface for dialing through an existing connection
// This enables true nested proxy chains (tunneling)
type TunnelDialer interface {
	// DialThroughConn establishes a proxy connection using an existing underlying connection
	DialThroughConn(conn net.Conn, network, address string) (net.Conn, error)
}
