package vless

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/binary"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/surge-proxy/surge-go/internal/protocol"
	"github.com/surge-proxy/surge-go/internal/utils"
	"golang.org/x/net/websocket"
)

// VLESS protocol version
const Version byte = 0

// Command types
const (
	CommandTCP byte = 0x01 // TCP
	CommandUDP byte = 0x02 // UDP
	CommandMux byte = 0x03 // Mux
)

// Address types
const (
	AddressTypeIPv4   byte = 0x01
	AddressTypeDomain byte = 0x02
	AddressTypeIPv6   byte = 0x03
)

// Client implements VLESS protocol client
type Client struct {
	config *Config
	uuid   []byte
}

// NewClient creates a new VLESS client
func NewClient(config *Config) (*Client, error) {
	if err := config.Validate(); err != nil {
		return nil, err
	}

	// Parse UUID to bytes
	uuid, err := UUIDToBytes(config.UUID)
	if err != nil {
		return nil, fmt.Errorf("invalid UUID: %v", err)
	}

	return &Client{
		config: config,
		uuid:   uuid,
	}, nil
}

// NewClientFromProxyConfig creates VLESS client from generic ProxyConfig
func NewClientFromProxyConfig(cfg *protocol.ProxyConfig) (*Client, error) {
	vlessConfig, err := FromProxyConfig(cfg)
	if err != nil {
		return nil, err
	}
	return NewClient(vlessConfig)
}

// DialContext implements protocol.Dialer interface
// DialContext implements protocol.Dialer interface
func (c *Client) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	// Parse target address
	host, portStr, err := net.SplitHostPort(address)
	if err != nil {
		return nil, fmt.Errorf("invalid address: %v", err)
	}

	port, err := strconv.Atoi(portStr)
	if err != nil {
		return nil, fmt.Errorf("invalid port: %v", err)
	}

	// Determine command
	var command byte
	if strings.HasPrefix(network, "tcp") {
		command = CommandTCP
	} else if strings.HasPrefix(network, "udp") {
		command = CommandUDP
	} else {
		return nil, fmt.Errorf("unsupported network: %s", network)
	}

	// Connect to VLESS server
	var rawConn net.Conn

	switch c.config.Network {
	case "tcp":
		log.Printf("VLESS: Dialing TCP to %s:%d", c.config.Server, c.config.Port)
		rawConn, err = c.dialTCP(ctx)
	case "ws":
		log.Printf("VLESS: Dialing WebSocket to %s:%d (Path: %s)", c.config.Server, c.config.Port, c.config.Path)
		rawConn, err = c.dialWebSocket(ctx)
	default:
		return nil, fmt.Errorf("unsupported transport: %s", c.config.Network)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to connect to server: %v", err)
	}

	// Send VLESS request
	log.Printf("VLESS: Sending request for %s:%d (Command: %d)", host, port, command)
	if err := c.sendRequest(rawConn, command, host, uint16(port)); err != nil {
		rawConn.Close()
		return nil, fmt.Errorf("failed to send request: %v", err)
	}

	// READ RESPONSE HEADER
	log.Printf("VLESS: Reading response header")
	if err := c.readResponse(rawConn); err != nil {
		log.Printf("VLESS: Read response failed: %v", err)
		rawConn.Close()
		return nil, fmt.Errorf("failed to read response header: %v", err)
	}
	log.Printf("VLESS: Connection established successfully")

	return rawConn, nil
}

// readResponse reads VLESS response header
func (c *Client) readResponse(conn net.Conn) error {
	// Response: [Version(1)] + [AddonsLen(1)] + [Addons(N)]
	buf := make([]byte, 2)
	if _, err := io.ReadFull(conn, buf); err != nil {
		return fmt.Errorf("failed to read response header: %v", err)
	}

	if buf[0] != Version {
		return fmt.Errorf("unexpected version: %d", buf[0])
	}

	addonsLen := int(buf[1])
	if addonsLen > 0 {
		addons := make([]byte, addonsLen)
		if _, err := io.ReadFull(conn, addons); err != nil {
			return fmt.Errorf("failed to read addons: %v", err)
		}
	}

	return nil
}

// dialTCP connects to VLESS server via TCP
func (c *Client) dialTCP(ctx context.Context) (net.Conn, error) {
	address := fmt.Sprintf("%s:%d", c.config.Server, c.config.Port)

	dialer := &net.Dialer{
		Timeout: 30 * time.Second,
	}

	network := utils.ResolveNetwork("tcp")
	rawConn, err := dialer.DialContext(ctx, network, address)
	if err != nil {
		return nil, err
	}

	// Wrap with TLS if enabled
	if c.config.TLS {
		tlsConfig := &tls.Config{
			ServerName:         c.config.GetSNI(),
			InsecureSkipVerify: c.config.AllowInsecure,
		}
		tlsConn := tls.Client(rawConn, tlsConfig)
		if err := tlsConn.HandshakeContext(ctx); err != nil {
			rawConn.Close()
			return nil, fmt.Errorf("TLS handshake failed: %v", err)
		}
		return tlsConn, nil
	}

	return rawConn, nil
}

// dialWebSocket connects to VLESS server via WebSocket
func (c *Client) dialWebSocket(ctx context.Context) (net.Conn, error) {
	scheme := "ws"
	if c.config.TLS {
		scheme = "wss"
	}

	path := c.config.Path
	if path == "" {
		path = "/"
	}

	uri := fmt.Sprintf("%s://%s:%d%s", scheme, c.config.Server, c.config.Port, path)

	// WebSocket configuration
	wsConfig, err := websocket.NewConfig(uri, fmt.Sprintf("http://%s", c.config.Server))
	if err != nil {
		return nil, err
	}

	// Set headers
	if c.config.Host != "" {
		wsConfig.Header.Set("Host", c.config.Host)
	}
	for k, v := range c.config.Headers {
		wsConfig.Header.Set(k, v)
	}

	// TLS configuration
	if c.config.TLS {
		wsConfig.TlsConfig = &tls.Config{
			ServerName:         c.config.GetSNI(),
			InsecureSkipVerify: c.config.AllowInsecure,
			NextProtos:         []string{"http/1.1"},
		}
	}

	// Dial WebSocket
	wsConn, err := websocket.DialConfig(wsConfig)
	if err != nil {
		return nil, fmt.Errorf("WebSocket dial failed: %v", err)
	}

	// Force binary frames
	wsConn.PayloadType = websocket.BinaryFrame

	return wsConn, nil
}

// sendRequest sends VLESS request
// Format: [version(1)] + [UUID(16)] + [addons_length(1)] + [addons] + [command(1)] + [port(2)] + [addr_type(1)] + [addr] + [padding]
func (c *Client) sendRequest(conn net.Conn, command byte, host string, port uint16) error {
	buf := new(bytes.Buffer)

	// 1. Version (1 byte)
	buf.WriteByte(Version)

	// 2. UUID (16 bytes)
	buf.Write(c.uuid)

	// 3. Addons length (1 byte) - no addons for now
	buf.WriteByte(0)

	// 4. Command (1 byte)
	buf.WriteByte(command)

	// 5. Port (2 bytes, big endian)
	portBytes := make([]byte, 2)
	binary.BigEndian.PutUint16(portBytes, port)
	buf.Write(portBytes)

	// 6. Address type + address
	if err := encodeAddress(buf, host); err != nil {
		return err
	}

	// Send request
	_, err := conn.Write(buf.Bytes())
	return err
}

// encodeAddress encodes address
func encodeAddress(buf *bytes.Buffer, host string) error {
	// Try to parse as IP
	ip := net.ParseIP(host)

	if ip != nil {
		// IP address
		if ipv4 := ip.To4(); ipv4 != nil {
			// IPv4
			buf.WriteByte(AddressTypeIPv4)
			buf.Write(ipv4)
		} else {
			// IPv6
			buf.WriteByte(AddressTypeIPv6)
			buf.Write(ip.To16())
		}
	} else {
		// Domain name
		if len(host) > 255 {
			return fmt.Errorf("domain name too long: %s", host)
		}
		buf.WriteByte(AddressTypeDomain)
		buf.WriteByte(byte(len(host)))
		buf.WriteString(host)
	}

	return nil
}

// Name implements protocol.Dialer interface
func (c *Client) Name() string {
	return c.config.Name
}

// Type implements protocol.Dialer interface
func (c *Client) Type() string {
	return "vless"
}

// Test implements protocol.Dialer interface
func (c *Client) Test(url string, timeout time.Duration) (int, error) {
	stats, err := c.TestLatency(url, timeout)
	if err != nil {
		return 0, err
	}
	return int(stats.Total), nil
}

// TestLatency implements protocol.LatencyTester interface
// TestLatency implements protocol.LatencyTester interface
func (c *Client) TestLatency(testURL string, timeout time.Duration) (protocol.LatencyStats, error) {
	var stats protocol.LatencyStats
	start := time.Now()

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	// 1. Measure TCP/Transport Connection Time
	// We need to manually dial to measure this step
	var rawConn net.Conn
	var err error

	dialStart := time.Now()
	switch c.config.Network {
	case "tcp":
		rawConn, err = c.dialTCP(ctx)
	case "ws":
		rawConn, err = c.dialWebSocket(ctx)
	default:
		return stats, fmt.Errorf("unsupported transport: %s", c.config.Network)
	}

	if err != nil {
		return stats, fmt.Errorf("transport dial failed: %v", err)
	}
	defer rawConn.Close()

	stats.TCPHandshake = time.Since(dialStart).Milliseconds()
	handshakeStart := time.Now()

	// 2. Measure VLESS Handshake (Request Sending)
	// We use http.NewRequest to parse the URL correctly
	req, err := http.NewRequestWithContext(ctx, "GET", testURL, nil)
	if err != nil {
		return stats, err
	}
	targetHost := req.URL.Hostname()
	targetPortStr := req.URL.Port()
	var targetPort int
	if targetPortStr == "" {
		if req.URL.Scheme == "https" {
			targetPort = 443
		} else {
			targetPort = 80
		}
	} else {
		p, _ := strconv.Atoi(targetPortStr)
		targetPort = p
	}

	// Determine command (TCP for HTTP test)
	command := CommandTCP

	// Send VLESS Request command
	if err := c.sendRequest(rawConn, command, targetHost, uint16(targetPort)); err != nil {
		return stats, fmt.Errorf("vless handshake failed: %v", err)
	}

	// READ RESPONSE HEADER (Critical Fix)
	if err := c.readResponse(rawConn); err != nil {
		return stats, fmt.Errorf("vless response error: %v", err)
	}

	stats.Handshake = time.Since(handshakeStart).Milliseconds()

	// 3. Measure HTTP RTT
	// We use http.Transport with a custom DialContext that returns this ALREADY ESTABLISHED connection.
	tr := &http.Transport{
		DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
			return rawConn, nil
		},
		MaxIdleConns:      1,
		DisableKeepAlives: true,
	}

	httpClient := &http.Client{
		Transport: tr,
		Timeout:   timeout,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}

	resp, err := httpClient.Do(req)
	if err != nil {
		return stats, err
	}
	resp.Body.Close()

	stats.Total = time.Since(start).Milliseconds()
	return stats, nil
}

// Close implements protocol.Dialer interface
func (c *Client) Close() error {
	// No resources to clean up
	return nil
}

// GetServerAddr implements protocol.ServerInfoProvider interface
func (c *Client) GetServerAddr() string {
	return fmt.Sprintf("%s:%d", c.config.Server, c.config.Port)
}

// DialThroughConn implements protocol.TunnelDialer interface
func (c *Client) DialThroughConn(conn net.Conn, network, address string) (net.Conn, error) {
	// Parse target address
	host, portStr, err := net.SplitHostPort(address)
	if err != nil {
		return nil, fmt.Errorf("invalid address: %v", err)
	}

	port, err := strconv.Atoi(portStr)
	if err != nil {
		return nil, fmt.Errorf("invalid port: %v", err)
	}

	// Determine command
	var command byte
	if strings.HasPrefix(network, "tcp") {
		command = CommandTCP
	} else if strings.HasPrefix(network, "udp") {
		command = CommandUDP
	} else {
		return nil, fmt.Errorf("unsupported network: %s", network)
	}

	// Handle transport layering if needed
	var transportConn net.Conn = conn

	switch c.config.Network {
	case "tcp":
		// Direct usage of underlying connection
	case "ws":
		// Perform WebSocket handshake over the existing connection
		scheme := "ws"
		if c.config.TLS {
			scheme = "wss"
		}
		path := c.config.Path
		if path == "" {
			path = "/"
		}
		uri := fmt.Sprintf("%s://%s:%d%s", scheme, c.config.Server, c.config.Port, path)

		wsConfig, err := websocket.NewConfig(uri, fmt.Sprintf("http://%s", c.config.Server))
		if err != nil {
			return nil, err
		}

		// Set headers
		if c.config.Host != "" {
			wsConfig.Header.Set("Host", c.config.Host)
		}
		for k, v := range c.config.Headers {
			wsConfig.Header.Set(k, v)
		}

		// Create WebSocket client over the existing connection
		wsClient, err := websocket.NewClient(wsConfig, conn)
		if err != nil {
			return nil, fmt.Errorf("WebSocket handshake failed: %v", err)
		}
		transportConn = wsClient
	default:
		return nil, fmt.Errorf("unsupported transport for tunneling: %s", c.config.Network)
	}

	// Send VLESS request
	if err := c.sendRequest(transportConn, command, host, uint16(port)); err != nil {
		return nil, fmt.Errorf("failed to send request: %v", err)
	}

	return transportConn, nil
}
