package policy

import (
	"context"
	"fmt"
	"net"
	"time"

	"github.com/surge-proxy/surge-go/internal/protocol"
)

// RelayGroup represents a chain/relay proxy group
// It connects through proxies in sequence: traffic -> proxy1 -> proxy2 -> ... -> destination
type RelayGroup struct {
	BaseGroup
	chainProxies []string // List of proxy names to chain
}

// NewRelayGroup creates a new relay group
func NewRelayGroup(name string, chainProxies []string, resolver ProxyResolver) *RelayGroup {
	return &RelayGroup{
		BaseGroup: BaseGroup{
			NameStr:     name,
			TypeStr:     "relay",
			ProxiesList: chainProxies,
			Resolver:    resolver,
		},
		chainProxies: chainProxies,
	}
}

// DialContext implements protocol.Dialer for relay chains
// It creates a chained connection through all proxies in sequence
func (g *RelayGroup) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	if len(g.chainProxies) == 0 {
		return nil, fmt.Errorf("relay group %s has no proxies configured", g.Name())
	}

	// Single proxy - just dial through it
	if len(g.chainProxies) == 1 {
		return g.SafeDial(ctx, network, address, g.chainProxies[0])
	}

	// Multiple proxies - validate chain
	for _, proxyName := range g.chainProxies {
		dialer := g.resolveProxy(proxyName)
		if dialer == nil {
			return nil, fmt.Errorf("relay group %s: proxy %s not found", g.Name(), proxyName)
		}
	}

	// Strategy for true chaining:
	// 1. Get first proxy dialer
	dialer1 := g.resolveProxy(g.chainProxies[0])
	if dialer1 == nil {
		return nil, fmt.Errorf("relay group %s: proxy %s not found", g.Name(), g.chainProxies[0])
	}

	// Get first proxy server address
	serverProvider, ok := dialer1.(protocol.ServerInfoProvider)
	if !ok {
		return nil, fmt.Errorf("proxy %s does not support server info", g.chainProxies[0])
	}
	serverAddr := serverProvider.GetServerAddr()

	// Connect to first proxy server directly
	conn, err := net.DialTimeout(network, serverAddr, 10*time.Second) // TODO: Configurable timeout
	if err != nil {
		return nil, fmt.Errorf("failed to connect to first proxy %s: %w", g.chainProxies[0], err)
	}

	// Tunnel through each proxy
	// For proxy i, we tunnel through the connection established to proxy i (or chain ending at i)
	// to connect to proxy i+1 server
	// Finally, tunnel to destination

	currentDialer := dialer1

	for i := 1; i < len(g.chainProxies); i++ {
		nextProxyName := g.chainProxies[i]
		nextDialer := g.resolveProxy(nextProxyName)
		if nextDialer == nil {
			conn.Close()
			return nil, fmt.Errorf("relay group %s: proxy %s not found", g.Name(), nextProxyName)
		}

		// Get next proxy server address
		nextServerProvider, ok := nextDialer.(protocol.ServerInfoProvider)
		if !ok {
			conn.Close()
			return nil, fmt.Errorf("proxy %s does not support server info", nextProxyName)
		}
		nextServerAddr := nextServerProvider.GetServerAddr()

		// Current dialer must support tunneling
		tunnelDialer, ok := currentDialer.(protocol.TunnelDialer)
		if !ok {
			conn.Close()
			return nil, fmt.Errorf("proxy %s does not support tunneling", currentDialer.Name())
		}

		// Tunnel to next server through current connection
		// This establishes a connection to nextServerAddr THROUGH currentDialer
		conn, err = tunnelDialer.DialThroughConn(conn, "tcp", nextServerAddr)
		if err != nil {
			conn.Close()
			return nil, fmt.Errorf("failed to tunnel from %s to %s: %w", currentDialer.Name(), nextProxyName, err)
		}

		currentDialer = nextDialer
	}

	// Finally, tunnel to destination using the last proxy
	lastTunnelDialer, ok := currentDialer.(protocol.TunnelDialer)
	if !ok {
		conn.Close()
		return nil, fmt.Errorf("last proxy %s does not support tunneling", currentDialer.Name())
	}

	return lastTunnelDialer.DialThroughConn(conn, network, address)
}

// resolveProxy resolves a proxy name to a Dialer
func (g *RelayGroup) resolveProxy(name string) protocol.Dialer {
	// Check special names
	if name == "DIRECT" {
		return protocol.NewDirectDialer("DIRECT")
	}
	if name == "REJECT" {
		return nil
	}

	// Check local proxies first
	if g.LocalProxies != nil {
		if dialer, ok := g.LocalProxies[name]; ok {
			return dialer
		}
	}

	// Use resolver
	if g.Resolver != nil {
		return g.Resolver(name)
	}

	return nil
}

// DialUDP not supported for relay chains
func (g *RelayGroup) DialUDP(ctx context.Context, network, address string) (net.PacketConn, error) {
	return nil, fmt.Errorf("UDP not supported for relay chains")
}

// Now returns the relay chain as a string showing all proxies
func (g *RelayGroup) Now() string {
	if len(g.chainProxies) == 0 {
		return ""
	}
	if len(g.chainProxies) == 1 {
		return g.chainProxies[0]
	}
	// Return full chain
	result := g.chainProxies[0]
	for i := 1; i < len(g.chainProxies); i++ {
		result += " → " + g.chainProxies[i]
	}
	return result
}

// UpdateProxies updates the relay chain
func (g *RelayGroup) UpdateProxies(proxies []string, localProxies map[string]protocol.Dialer) {
	g.chainProxies = proxies
	g.ProxiesList = proxies
	g.LocalProxies = localProxies
}
