package server

import (
	"context"
	"encoding/binary"
	"fmt"
	"io"
	"log"
	"net"
	"sync"
	"time"

	"github.com/surge-proxy/surge-go/internal/protocol"
)

// SOCKS5 constants
const (
	SOCKS5Version = 0x05

	// Authentication methods
	AuthNone     = 0x00
	AuthGSSAPI   = 0x01
	AuthPassword = 0x02
	AuthNoAccept = 0xFF

	// Commands
	CmdConnect  = 0x01
	CmdBind     = 0x02
	CmdUDPAssoc = 0x03

	// Address types
	AddrTypeIPv4   = 0x01
	AddrTypeDomain = 0x03
	AddrTypeIPv6   = 0x04

	// Reply codes
	ReplySuccess              = 0x00
	ReplyServerFailure        = 0x01
	ReplyNotAllowed           = 0x02
	ReplyNetworkUnreachable   = 0x03
	ReplyHostUnreachable      = 0x04
	ReplyConnectionRefused    = 0x05
	ReplyTTLExpired           = 0x06
	ReplyCommandNotSupported  = 0x07
	ReplyAddrTypeNotSupported = 0x08
)

// SOCKS5Server implements SOCKS5 proxy server
type SOCKS5Server struct {
	addr    string
	dialer  protocol.Dialer
	handler RequestHandler
	ln      net.Listener
	mu      sync.Mutex
	closed  bool
	wg      sync.WaitGroup
}

// NewSOCKS5Server creates a new SOCKS5 proxy server
func NewSOCKS5Server(addr string, handler RequestHandler) *SOCKS5Server {
	return &SOCKS5Server{
		addr:    addr,
		handler: handler,
	}
}

// NewSOCKS5ServerWithDialer creates SOCKS5 proxy server with a fixed dialer
func NewSOCKS5ServerWithDialer(addr string, dialer protocol.Dialer) *SOCKS5Server {
	return &SOCKS5Server{
		addr:   addr,
		dialer: dialer,
	}
}

// Start starts the SOCKS5 proxy server
func (s *SOCKS5Server) Start() error {
	ln, err := net.Listen("tcp", s.addr)
	if err != nil {
		return fmt.Errorf("failed to listen on %s: %v", s.addr, err)
	}

	s.mu.Lock()
	s.ln = ln
	s.mu.Unlock()

	log.Printf("SOCKS5 proxy server listening on %s", s.addr)

	for {
		conn, err := ln.Accept()
		if err != nil {
			s.mu.Lock()
			closed := s.closed
			s.mu.Unlock()
			if closed {
				return nil
			}
			log.Printf("Accept error: %v", err)
			continue
		}

		s.wg.Add(1)
		go s.handleConnection(conn)
	}
}

// Stop stops the SOCKS5 proxy server (Immediate)
func (s *SOCKS5Server) Stop() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.closed = true
	if s.ln != nil {
		return s.ln.Close()
	}
	return nil
}

// Shutdown gracefully stops the server
func (s *SOCKS5Server) Shutdown(ctx context.Context) error {
	// Stop accepting new connections
	s.Stop()

	// Wait for active connections
	c := make(chan struct{})
	go func() {
		s.wg.Wait()
		close(c)
	}()

	select {
	case <-c:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

// Addr returns the server address
func (s *SOCKS5Server) Addr() string {
	return s.addr
}

// handleConnection handles a single SOCKS5 connection
func (s *SOCKS5Server) handleConnection(clientConn net.Conn) {
	defer s.wg.Done()
	defer clientConn.Close()

	// Set read deadline
	clientConn.SetReadDeadline(time.Now().Add(30 * time.Second))

	// 1. Authentication negotiation
	if err := s.handleAuth(clientConn); err != nil {
		log.Printf("Auth failed: %v", err)
		return
	}

	// 2. Request
	targetAddr, err := s.handleRequest(clientConn)
	if err != nil {
		log.Printf("Request failed: %v", err)
		return
	}

	// Reset deadline
	clientConn.SetReadDeadline(time.Time{})

	// 3. Connect to target
	s.handleConnect(clientConn, targetAddr)
}

// handleAuth handles SOCKS5 authentication
func (s *SOCKS5Server) handleAuth(conn net.Conn) error {
	// Read version and methods
	buf := make([]byte, 2)
	if _, err := io.ReadFull(conn, buf); err != nil {
		return err
	}

	version := buf[0]
	nMethods := buf[1]

	if version != SOCKS5Version {
		return fmt.Errorf("unsupported SOCKS version: %d", version)
	}

	// Read methods
	methods := make([]byte, nMethods)
	if _, err := io.ReadFull(conn, methods); err != nil {
		return err
	}

	// We only support no authentication
	hasNoAuth := false
	for _, method := range methods {
		if method == AuthNone {
			hasNoAuth = true
			break
		}
	}

	if !hasNoAuth {
		// No acceptable method
		conn.Write([]byte{SOCKS5Version, AuthNoAccept})
		return fmt.Errorf("no acceptable auth method")
	}

	// Accept no authentication
	_, err := conn.Write([]byte{SOCKS5Version, AuthNone})
	return err
}

// handleRequest handles SOCKS5 request and returns target address
func (s *SOCKS5Server) handleRequest(conn net.Conn) (string, error) {
	// Read request header: VER CMD RSV ATYP
	buf := make([]byte, 4)
	if _, err := io.ReadFull(conn, buf); err != nil {
		return "", err
	}

	version := buf[0]
	cmd := buf[1]
	addrType := buf[3]

	if version != SOCKS5Version {
		s.sendReply(conn, ReplyServerFailure, "", 0)
		return "", fmt.Errorf("unsupported version: %d", version)
	}

	if cmd != CmdConnect {
		s.sendReply(conn, ReplyCommandNotSupported, "", 0)
		return "", fmt.Errorf("unsupported command: %d", cmd)
	}

	// Read address
	var addr string
	var port uint16

	switch addrType {
	case AddrTypeIPv4:
		ipBuf := make([]byte, 4)
		if _, err := io.ReadFull(conn, ipBuf); err != nil {
			return "", err
		}
		addr = net.IP(ipBuf).String()

	case AddrTypeDomain:
		lenBuf := make([]byte, 1)
		if _, err := io.ReadFull(conn, lenBuf); err != nil {
			return "", err
		}
		domainBuf := make([]byte, lenBuf[0])
		if _, err := io.ReadFull(conn, domainBuf); err != nil {
			return "", err
		}
		addr = string(domainBuf)

	case AddrTypeIPv6:
		ipBuf := make([]byte, 16)
		if _, err := io.ReadFull(conn, ipBuf); err != nil {
			return "", err
		}
		addr = net.IP(ipBuf).String()

	default:
		s.sendReply(conn, ReplyAddrTypeNotSupported, "", 0)
		return "", fmt.Errorf("unsupported address type: %d", addrType)
	}

	// Read port
	portBuf := make([]byte, 2)
	if _, err := io.ReadFull(conn, portBuf); err != nil {
		return "", err
	}
	port = binary.BigEndian.Uint16(portBuf)

	targetAddr := fmt.Sprintf("%s:%d", addr, port)
	return targetAddr, nil
}

// handleConnect connects to the target and relays data
func (s *SOCKS5Server) handleConnect(clientConn net.Conn, targetAddr string) {
	// Get dialer
	dialer := s.getDialer("tcp", targetAddr, clientConn.RemoteAddr().String())

	// Connect to target
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	targetConn, err := dialer.DialContext(ctx, "tcp", targetAddr)
	if err != nil {
		log.Printf("Failed to connect to %s: %v", targetAddr, err)
		s.sendReply(clientConn, ReplyHostUnreachable, "", 0)
		return
	}
	defer targetConn.Close()

	// Send success reply
	s.sendReply(clientConn, ReplySuccess, "0.0.0.0", 0)

	// Start bidirectional relay
	s.relay(clientConn, targetConn)
}

// sendReply sends SOCKS5 reply
func (s *SOCKS5Server) sendReply(conn net.Conn, reply byte, bindAddr string, bindPort uint16) {
	// VER REP RSV ATYP BND.ADDR BND.PORT
	resp := []byte{SOCKS5Version, reply, 0x00}

	// Use IPv4 address type for simplicity
	resp = append(resp, AddrTypeIPv4)
	resp = append(resp, []byte{0, 0, 0, 0}...) // 0.0.0.0
	resp = append(resp, []byte{0, 0}...)       // port 0

	conn.Write(resp)
}

// getDialer returns the appropriate dialer for the request
func (s *SOCKS5Server) getDialer(network, address, source string) protocol.Dialer {
	// If handler is set, use it
	if s.handler != nil {
		if dialer := s.handler.HandleRequest(context.Background(), network, address, source); dialer != nil {
			return dialer
		}
	}

	// If fixed dialer is set, use it
	if s.dialer != nil {
		return s.dialer
	}

	// Otherwise use direct connection
	return protocol.NewDirectDialer("DIRECT")
}

// relay performs bidirectional copy between two connections
func (s *SOCKS5Server) relay(conn1, conn2 net.Conn) {
	var wg sync.WaitGroup
	wg.Add(2)

	// Copy from conn1 to conn2
	go func() {
		defer wg.Done()
		io.Copy(conn2, conn1)
		if tcpConn, ok := conn2.(*net.TCPConn); ok {
			tcpConn.CloseWrite()
		}
	}()

	// Copy from conn2 to conn1
	go func() {
		defer wg.Done()
		io.Copy(conn1, conn2)
		if tcpConn, ok := conn1.(*net.TCPConn); ok {
			tcpConn.CloseWrite()
		}
	}()

	wg.Wait()
}
