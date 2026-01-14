package policy

import (
	"context"
	"fmt"
	"net"
	"time"

	"github.com/surge-proxy/surge-go/internal/config"
	"github.com/surge-proxy/surge-go/internal/protocol"
)

// ChainedDialer wraps a proxy to dial through another proxy
// This enables nested proxy connections for relay chains
type ChainedDialer struct {
	underlying protocol.Dialer // The proxy to use (wraps this)
	nextTarget string          // Server address of the next proxy in chain
	nextDialer protocol.Dialer // The next proxy dialer (for final connection)
}

// NewChainedDialer creates a dialer that uses 'underlying' to connect to 'nextTarget'
// then uses that connection as transport for 'nextDialer'
func NewChainedDialer(underlying protocol.Dialer, nextTarget string, nextDialer protocol.Dialer) *ChainedDialer {
	return &ChainedDialer{
		underlying: underlying,
		nextTarget: nextTarget,
		nextDialer: nextDialer,
	}
}

// DialContext implements protocol.Dialer
// It uses the underlying proxy to connect to nextTarget,
// then uses that connection to establish the next hop
func (cd *ChainedDialer) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	// This is complex because we need to:
	// 1. Use underlying proxy to connect to nextTarget
	// 2. Through that connection, make the next proxy work

	// Problem: Standard Dialer interface doesn't support using an existing connection
	// We need a way to "tunnel" through the underlying connection

	// For now, just delegate to nextDialer
	// TODO: Implement proper tunneling
	return cd.nextDialer.DialContext(ctx, network, address)
}

func (cd *ChainedDialer) Name() string {
	return fmt.Sprintf("Chain[%s->%s]", cd.underlying.Name(), cd.nextDialer.Name())
}

func (cd *ChainedDialer) Type() string {
	return "chained"
}

func (cd *ChainedDialer) Test(url string, timeout time.Duration) (int, error) {
	// Testing a chain is complex - for now delegate to final dialer
	return cd.nextDialer.Test(url, timeout)
}

func (cd *ChainedDialer) Close() error {
	// Close both underlying and next
	var err1, err2 error
	if cd.underlying != nil {
		err1 = cd.underlying.Close()
	}
	if cd.nextDialer != nil {
		err2 = cd.nextDialer.Close()
	}
	if err1 != nil {
		return err1
	}
	return err2
}

// ProxyInfoProvider is an interface for getting proxy server information
// This allows us to get the server address from a Dialer
type ProxyInfoProvider interface {
	GetProxyInfo() *ProxyInfo
}

// ProxyInfo contains server information for a proxy
type ProxyInfo struct {
	Server string
	Port   int
}

// getProxyServerAddress attempts to extract server address from a dialer
func getProxyServerAddress(dialer protocol.Dialer, proxyConfigs []*config.ProxyConfig) string {
	// Try to get from ProxyInfoProvider interface
	if provider, ok := dialer.(ProxyInfoProvider); ok {
		info := provider.GetProxyInfo()
		if info != nil {
			return fmt.Sprintf("%s:%d", info.Server, info.Port)
		}
	}

	// Fallback: Search in proxy configs by name
	name := dialer.Name()
	for _, cfg := range proxyConfigs {
		if cfg.Name == name {
			return fmt.Sprintf("%s:%d", cfg.Server, cfg.Port)
		}
	}

	return ""
}
