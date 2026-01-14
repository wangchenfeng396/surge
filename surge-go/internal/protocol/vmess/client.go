package vmess

import (
	"context"
	"crypto/tls"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/surge-proxy/surge-go/internal/protocol"
	"github.com/surge-proxy/surge-go/internal/utils"
	"golang.org/x/net/websocket"
)

// Client implements VMess protocol client
type Client struct {
	config *Config
	cmdKey []byte
	uuid   []byte
}

// NewClient creates a new VMess client
func NewClient(config *Config) (*Client, error) {
	if err := config.Validate(); err != nil {
		return nil, err
	}

	// Parse UUID to bytes
	uuid, err := UUIDToBytes(config.UUID)
	if err != nil {
		return nil, fmt.Errorf("invalid UUID: %v", err)
	}

	// Generate command key
	cmdKey := NewCmdKey(uuid)

	return &Client{
		config: config,
		cmdKey: cmdKey,
		uuid:   uuid,
	}, nil
}

// NewClientFromProxyConfig creates VMess client from generic ProxyConfig
func NewClientFromProxyConfig(cfg *protocol.ProxyConfig) (*Client, error) {
	vmessConfig, err := FromProxyConfig(cfg)
	if err != nil {
		return nil, err
	}
	return NewClient(vmessConfig)
}

// DialContext implements protocol.Dialer interface
func (c *Client) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
	// Parse target address
	host, portStr, err := net.SplitHostPort(address)
	if err != nil {
		return nil, fmt.Errorf("invalid address: %v", err)
	}

	port, err := net.LookupPort(network, portStr)
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

	// Connect to VMess server
	var rawConn net.Conn

	proxyNetwork := c.config.Network
	if proxyNetwork == "tcp" {
		proxyNetwork = utils.ResolveNetwork("tcp")
	}

	fmt.Printf("[VMess] Dialing %s via %s (Network: %s)...\n", address, c.config.Network, proxyNetwork)

	switch c.config.Network {
	case "tcp":
		rawConn, err = c.dialTCP(ctx, proxyNetwork)
	case "ws":
		// WebSocket handles its own dialing, but we might need to enforce IPv4 on the underlying dialer if exposed.
		// For now, let's focus on TCP.
		rawConn, err = c.dialWebSocket(ctx)
	default:
		return nil, fmt.Errorf("unsupported transport: %s", c.config.Network)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to connect to server: %v", err)
	}

	// Perform VMess handshake
	conn, err := c.handshake(rawConn, command, host, uint16(port))
	if err != nil {
		fmt.Printf("[VMess] Handshake failed: %v\n", err)
		rawConn.Close()
		return nil, fmt.Errorf("handshake failed: %v", err)
	}
	fmt.Printf("[VMess] Handshake success. Returning connection.\n")

	return conn, nil
}

// dialTCP connects to VMess server via TCP
func (c *Client) dialTCP(ctx context.Context, network string) (net.Conn, error) {
	address := fmt.Sprintf("%s:%d", c.config.Server, c.config.Port)

	dialer := &net.Dialer{
		Timeout: 30 * time.Second,
	}

	rawConn, err := dialer.DialContext(ctx, network, address)
	if err != nil {
		return nil, err
	}

	// Wrap with TLS if enabled
	if c.config.TLS {
		tlsConfig := &tls.Config{
			ServerName:         c.getSNI(),
			InsecureSkipVerify: c.config.AllowInsecure,
		}
		tlsConn := tls.Client(rawConn, tlsConfig)
		if err := tlsConn.Handshake(); err != nil {
			rawConn.Close()
			return nil, fmt.Errorf("TLS handshake failed: %v", err)
		}
		return tlsConn, nil
	}

	return rawConn, nil
}

// dialWebSocket connects to VMess server via WebSocket
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

	// Determine Origin
	originScheme := "http"
	if c.config.TLS {
		originScheme = "https"
	}
	origin := fmt.Sprintf("%s://%s", originScheme, c.config.Server)
	if c.config.Host != "" {
		origin = fmt.Sprintf("%s://%s", originScheme, c.config.Host)
	}

	// WebSocket configuration
	wsConfig, err := websocket.NewConfig(uri, origin)
	if err != nil {
		return nil, err
	}
	// Set subprotocol for V2Ray/VMess compatibility
	wsConfig.Protocol = []string{"vmess"}

	// Set headers
	if c.config.Host != "" {
		wsConfig.Header.Set("Host", c.config.Host)
	} else if c.config.SNI != "" {
		// Fallback to SNI as Host if Host not explicitly set (common for WS+TLS)
		wsConfig.Header.Set("Host", c.config.SNI)
	}

	// Set standard headers
	wsConfig.Header.Set("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
	for k, v := range c.config.Headers {
		wsConfig.Header.Set(k, v)
	}

	// TLS configuration
	if c.config.TLS {
		wsConfig.TlsConfig = &tls.Config{
			ServerName:         c.getSNI(),
			InsecureSkipVerify: c.config.AllowInsecure,
			NextProtos:         []string{"http/1.1"},
		}
	}

	// Dial WebSocket
	fmt.Printf("[VMess] Dialing WebSocket to %s...\n", uri)
	wsConn, err := websocket.DialConfig(wsConfig)
	if err != nil {
		fmt.Printf("[VMess] WebSocket handshake failed: %v\n", err)
		return nil, fmt.Errorf("WebSocket dial failed: %v", err)
	}
	fmt.Printf("[VMess] WebSocket handshake success (Protocol: %s)\n", wsConfig.Protocol)

	// Force binary frames (required for VMess)
	wsConn.PayloadType = websocket.BinaryFrame

	return wsConn, nil
}

// getSNI returns SNI for TLS
func (c *Client) getSNI() string {
	if c.config.SNI != "" {
		return c.config.SNI
	}
	if c.config.Host != "" {
		return c.config.Host
	}
	return c.config.Server
}

// handshake performs VMess handshake
func (c *Client) handshake(rawConn net.Conn, command byte, address string, port uint16) (net.Conn, error) {
	// Create request header
	requestHeader := CreateRequestHeader(command, address, port, c.uuid, c.config.Security)

	// Encode request header
	fmt.Printf("[VMess] Handshake config: AEAD=%v Security=%v\n", c.config.AEAD, c.config.Security)

	var (
		encodedHeader []byte
		bodyKey       []byte
		bodyIV        []byte
		authid        []byte
		legacyNow     int64
		err           error
	)

	if c.config.AEAD {
		requestHeader.Option |= RequestOptionAuthenticatedLength
		fmt.Printf("[VMess] Encoding AEAD header with UUID: %x\n", c.uuid)
		encodedHeader, bodyKey, bodyIV, authid, err = EncodeRequestHeader(requestHeader, c.uuid)
	} else {
		fmt.Printf("[VMess] Encoding Legacy header with CmdKey: %x\n", c.cmdKey)
		encodedHeader, bodyKey, bodyIV, legacyNow, err = EncodeLegacyRequestHeader(requestHeader, c.cmdKey)
	}

	if err != nil {
		return nil, fmt.Errorf("failed to encode header: %v", err)
	}

	// Send request header
	if _, err := rawConn.Write(encodedHeader); err != nil {
		return nil, fmt.Errorf("failed to send header: %v", err)
	}
	fmt.Printf("[VMess] Header sent (%d bytes), waiting for response...\n", len(encodedHeader))

	// Create AEAD cipher for body encryption
	security := c.config.Security
	if security == SecurityAuto {
		security = SecurityAES128GCM
	}

	// Create AEAD cipher
	aead, err := CreateAEADCipher(security, bodyKey)
	if err != nil {
		return nil, fmt.Errorf("failed to create AEAD cipher: %v", err)
	}

	// Wrap connection
	var conn net.Conn
	if c.config.AEAD {
		conn = &vmessConn{
			Conn:          rawConn,
			writer:        NewChunkWriter(rawConn, aead, bodyIV),
			reader:        NewChunkReader(rawConn, aead, bodyIV),
			requestHeader: requestHeader,
		}
		// Read AEAD response
		_, err = DecodeResponseHeader(c.uuid, rawConn, authid)
	} else {
		// Legacy mode body encryption is usually different but let's see.
		// Standard VMess legacy uses simple body encryption.
		// For now, we use the same ChunkReader/Writer if AEAD is not used but the structure remains.
		// Actually, VMess Legacy and AEAD share the same body structure if Options specify it.
		conn = &vmessConn{
			Conn:          rawConn,
			writer:        NewChunkWriter(rawConn, aead, bodyIV),
			reader:        NewChunkReader(rawConn, aead, bodyIV),
			requestHeader: requestHeader,
		}
		// Read Legacy response
		_, err = DecodeLegacyResponseHeader(c.cmdKey, rawConn, legacyNow)
	}

	if err != nil {
		rawConn.Close()
		return nil, fmt.Errorf("failed to decode response header: %v", err)
	}

	return conn, nil
}

// Name implements protocol.Dialer interface
func (c *Client) Name() string {
	return c.config.Name
}

// Type implements protocol.Dialer interface
func (c *Client) Type() string {
	return "vmess"
}

// Test implements protocol.Dialer interface
func (c *Client) Test(url string, timeout time.Duration) (int, error) {
	start := time.Now()

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	// Create HTTP client with this proxy
	client := &http.Client{
		Timeout: timeout,
		Transport: &http.Transport{
			DialContext: c.DialContext,
		},
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}

	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return 0, err
	}

	resp, err := client.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	// Read and discard response body
	io.Copy(io.Discard, resp.Body)

	latency := time.Since(start).Milliseconds()
	return int(latency), nil
}

// Close implements protocol.Dialer interface
func (c *Client) Close() error {
	// No resources to clean up in current implementation
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

	port, err := net.LookupPort(network, portStr)
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
		// Set subprotocol
		wsConfig.Protocol = []string{"vmess"}

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

	// Perform VMess handshake
	vmessConn, err := c.handshake(transportConn, command, host, uint16(port))
	if err != nil {
		// Only close if we created a wrapper (like WS), otherwise caller handles close?
		// Usually TunnelDialer should not close the underlying conn on failure if it fails BEFORE consuming it?
		// But here we likely consumed some bytes or wrote some.
		// Safe to let caller handle close or close here?
		// Caller (RelayGroup) closes 'conn' on error.
		return nil, fmt.Errorf("handshake failed: %v", err)
	}

	return vmessConn, nil
}

// vmessConn wraps a connection with VMess encryption/decryption
type vmessConn struct {
	net.Conn
	writer        *ChunkWriter
	reader        *ChunkReader
	requestHeader *RequestHeader
}

// Read reads decrypted data
func (c *vmessConn) Read(b []byte) (int, error) {
	return c.reader.Read(b)
}

// Write writes encrypted data
func (c *vmessConn) Write(b []byte) (int, error) {
	return c.writer.Write(b)
}
