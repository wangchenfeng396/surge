package trojan

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/surge-proxy/surge-go/internal/protocol"
)

// Trojan command types
const (
	CommandConnect = 0x01 // TCP connect
	CommandUDP     = 0x03 // UDP associate
)

// Address types (SOCKS5 format)
const (
	AddressTypeIPv4   = 0x01
	AddressTypeDomain = 0x03
	AddressTypeIPv6   = 0x04
)

// CRLF constant
var CRLF = []byte{0x0D, 0x0A}

// Client implements Trojan protocol client
type Client struct {
	config       *Config
	passwordHash string
}

// NewClient creates a new Trojan client
func NewClient(config *Config) (*Client, error) {
	if err := config.Validate(); err != nil {
		return nil, err
	}

	// Generate password hash
	passwordHash := GeneratePasswordHash(config.Password)

	return &Client{
		config:       config,
		passwordHash: passwordHash,
	}, nil
}

// NewClientFromProxyConfig creates Trojan client from generic ProxyConfig
func NewClientFromProxyConfig(cfg *protocol.ProxyConfig) (*Client, error) {
	trojanConfig, err := FromProxyConfig(cfg)
	if err != nil {
		return nil, err
	}
	return NewClient(trojanConfig)
}

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
		command = CommandConnect
	} else if strings.HasPrefix(network, "udp") {
		command = CommandUDP
	} else {
		return nil, fmt.Errorf("unsupported network: %s", network)
	}

	// Connect to Trojan server with TLS
	serverAddr := fmt.Sprintf("%s:%d", c.config.Server, c.config.Port)

	dialer := &net.Dialer{
		Timeout: 30 * time.Second,
	}

	rawConn, err := dialer.DialContext(ctx, "tcp", serverAddr)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to server: %v", err)
	}

	// Wrap with TLS (Trojan always uses TLS)
	tlsConfig := &tls.Config{
		ServerName:         c.config.GetSNI(),
		InsecureSkipVerify: c.config.AllowInsecure,
	}

	tlsConn := tls.Client(rawConn, tlsConfig)
	if err := tlsConn.HandshakeContext(ctx); err != nil {
		rawConn.Close()
		return nil, fmt.Errorf("TLS handshake failed: %v", err)
	}

	// Send Trojan request
	if err := c.sendRequest(tlsConn, command, host, uint16(port)); err != nil {
		tlsConn.Close()
		return nil, fmt.Errorf("failed to send request: %v", err)
	}

	// Return the TLS connection (Trojan has no response header)
	return tlsConn, nil
}

// sendRequest sends Trojan request to server
// Format: password_hash + CRLF + command + address_type + address + port + CRLF
func (c *Client) sendRequest(conn net.Conn, command byte, host string, port uint16) error {
	buf := new(bytes.Buffer)

	// 1. Password hash (56 bytes hex string)
	buf.WriteString(c.passwordHash)

	// 2. CRLF
	buf.Write(CRLF)

	// 3. Command (1 byte)
	buf.WriteByte(command)

	// 4. Address type + address + port (SOCKS5 format)
	if err := encodeAddress(buf, host, port); err != nil {
		return err
	}

	// 5. CRLF
	buf.Write(CRLF)

	// Send request
	_, err := conn.Write(buf.Bytes())
	return err
}

// encodeAddress encodes address in SOCKS5 format
func encodeAddress(buf *bytes.Buffer, host string, port uint16) error {
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

	// Port (2 bytes, big endian)
	portBytes := make([]byte, 2)
	binary.BigEndian.PutUint16(portBytes, port)
	buf.Write(portBytes)

	return nil
}

// Name implements protocol.Dialer interface
func (c *Client) Name() string {
	return c.config.Name
}

// Type implements protocol.Dialer interface
func (c *Client) Type() string {
	return "trojan"
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
		command = CommandConnect
	} else if strings.HasPrefix(network, "udp") {
		command = CommandUDP
	} else {
		return nil, fmt.Errorf("unsupported network: %s", network)
	}

	// Wrap with TLS (Trojan always uses TLS)
	tlsConfig := &tls.Config{
		ServerName:         c.config.GetSNI(),
		InsecureSkipVerify: c.config.AllowInsecure,
	}

	// Create a context for handshake with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second) // Todo: configurable timeout
	defer cancel()

	tlsConn := tls.Client(conn, tlsConfig)
	if err := tlsConn.HandshakeContext(ctx); err != nil {
		// Do not close underlaying conn here to allow caller handling?
		// But TLS handshake might have written data...
		// Usually if handshake fails, the stream is garbage.
		// Return error, caller will likely close conn due to error.
		return nil, fmt.Errorf("TLS handshake failed: %v", err)
	}

	// Send Trojan request
	if err := c.sendRequest(tlsConn, command, host, uint16(port)); err != nil {
		// Same here
		return nil, fmt.Errorf("failed to send request: %v", err)
	}

	// Return the TLS connection (Trojan has no response header)
	return tlsConn, nil
}
