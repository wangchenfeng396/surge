package proxy

import (
	"bufio"
	"fmt"
	"log"
	"net"
	"net/http"
	"strings"
	"time"

	"github.com/surge-proxy/surge-go/internal/config"
	"github.com/surge-proxy/surge-go/internal/stats"
)

// Server represents the proxy server
type Server struct {
	config   *config.Config
	stats    *stats.Collector
	listener net.Listener
	socks5   net.Listener
}

// NewServer creates a new proxy server
func NewServer(cfg *config.Config, collector *stats.Collector) *Server {
	return &Server{
		config: cfg,
		stats:  collector,
	}
}

// Start starts the proxy server
func (s *Server) Start() error {
	// Start HTTP/HTTPS proxy
	addr := fmt.Sprintf("%s:%d", s.config.Host, s.config.Port)
	listener, err := net.Listen("tcp", addr)
	if err != nil {
		return fmt.Errorf("failed to start HTTP proxy: %w", err)
	}
	s.listener = listener
	log.Printf("HTTP/HTTPS proxy listening on %s", addr)

	// Start SOCKS5 proxy
	socks5Addr := fmt.Sprintf("%s:%d", s.config.Host, s.config.SOCKS5Port)
	socks5Listener, err := net.Listen("tcp", socks5Addr)
	if err != nil {
		listener.Close()
		return fmt.Errorf("failed to start SOCKS5 proxy: %w", err)
	}
	s.socks5 = socks5Listener
	log.Printf("SOCKS5 proxy listening on %s", socks5Addr)

	// Handle HTTP/HTTPS connections
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				log.Printf("Accept error: %v", err)
				continue
			}
			go s.handleHTTPConnection(conn)
		}
	}()

	// Handle SOCKS5 connections
	go func() {
		for {
			conn, err := socks5Listener.Accept()
			if err != nil {
				log.Printf("SOCKS5 accept error: %v", err)
				continue
			}
			go s.handleSOCKS5Connection(conn)
		}
	}()

	return nil
}

// Stop stops the proxy server
func (s *Server) Stop() error {
	if s.listener != nil {
		s.listener.Close()
	}
	if s.socks5 != nil {
		s.socks5.Close()
	}
	return nil
}

// handleHTTPConnection handles HTTP/HTTPS proxy connections
func (s *Server) handleHTTPConnection(clientConn net.Conn) {
	defer clientConn.Close()

	s.stats.IncrementConnection()
	defer s.stats.DecrementConnection()

	reader := bufio.NewReader(clientConn)

	// Read the first line to determine if it's CONNECT (HTTPS) or regular HTTP
	firstLine, err := reader.ReadString('\n')
	if err != nil {
		return
	}

	parts := strings.Fields(firstLine)
	if len(parts) < 3 {
		return
	}

	method := parts[0]
	target := parts[1]

	if method == "CONNECT" {
		s.handleHTTPS(clientConn, target)
	} else {
		s.handleHTTP(clientConn, reader, firstLine, target)
	}
}

// handleHTTPS handles HTTPS CONNECT requests
func (s *Server) handleHTTPS(clientConn net.Conn, target string) {
	// Extract host
	host := target
	if !strings.Contains(host, ":") {
		host = host + ":443"
	}

	// Check if blocked
	if s.config.IsBlocked(host) {
		clientConn.Write([]byte("HTTP/1.1 403 Forbidden\r\n\r\n"))
		log.Printf("Blocked HTTPS request to %s", host)
		return
	}

	// Connect to remote server
	remoteConn, err := net.DialTimeout("tcp", host, time.Duration(s.config.Timeout)*time.Second)
	if err != nil {
		clientConn.Write([]byte("HTTP/1.1 502 Bad Gateway\r\n\r\n"))
		log.Printf("Failed to connect to %s: %v", host, err)
		return
	}
	defer remoteConn.Close()

	// Send connection established
	clientConn.Write([]byte("HTTP/1.1 200 Connection Established\r\n\r\n"))
	log.Printf("HTTPS: %s", host)

	// Bidirectional copy
	s.transfer(clientConn, remoteConn)
}

// handleHTTP handles regular HTTP requests
func (s *Server) handleHTTP(clientConn net.Conn, reader *bufio.Reader, firstLine, target string) {
	// Parse request
	req, err := http.ReadRequest(reader)
	if err != nil {
		return
	}

	host := req.Host
	if host == "" {
		host = req.URL.Host
	}

	// Check if blocked
	if s.config.IsBlocked(host) {
		clientConn.Write([]byte("HTTP/1.1 403 Forbidden\r\n\r\n"))
		log.Printf("Blocked HTTP request to %s", host)
		return
	}

	// Add default port if missing
	if !strings.Contains(host, ":") {
		host = host + ":80"
	}

	// Connect to remote server
	remoteConn, err := net.DialTimeout("tcp", host, time.Duration(s.config.Timeout)*time.Second)
	if err != nil {
		clientConn.Write([]byte("HTTP/1.1 502 Bad Gateway\r\n\r\n"))
		log.Printf("Failed to connect to %s: %v", host, err)
		return
	}
	defer remoteConn.Close()

	log.Printf("HTTP: %s", host)

	// Forward the request
	if err := req.Write(remoteConn); err != nil {
		return
	}

	// Copy response back
	s.transfer(clientConn, remoteConn)
}

// transfer handles bidirectional data transfer
func (s *Server) transfer(client, remote net.Conn) {
	done := make(chan struct{}, 2)

	// Client -> Remote
	go func() {
		uploaded := s.copyWithStats(remote, client, true)
		s.stats.RecordUpload(uploaded, 0, "")
		done <- struct{}{}
	}()

	// Remote -> Client
	go func() {
		downloaded := s.copyWithStats(client, remote, false)
		s.stats.RecordDownload(downloaded, 0, "")
		done <- struct{}{}
	}()

	// Wait for both directions to complete
	<-done
	<-done
}

// copyWithStats copies data and returns bytes transferred
func (s *Server) copyWithStats(dst, src net.Conn, isUpload bool) uint64 {
	buf := make([]byte, s.config.BufferSize)
	var total uint64

	for {
		src.SetReadDeadline(time.Now().Add(time.Duration(s.config.Timeout) * time.Second))
		n, err := src.Read(buf)
		if n > 0 {
			total += uint64(n)
			if _, writeErr := dst.Write(buf[:n]); writeErr != nil {
				break
			}
		}
		if err != nil {
			break
		}
	}

	return total
}

// handleSOCKS5Connection handles SOCKS5 proxy connections
func (s *Server) handleSOCKS5Connection(clientConn net.Conn) {
	defer clientConn.Close()

	s.stats.IncrementConnection()
	defer s.stats.DecrementConnection()

	// SOCKS5 handshake
	buf := make([]byte, 256)

	// Read version and methods
	n, err := clientConn.Read(buf)
	if err != nil || n < 2 {
		return
	}

	version := buf[0]
	if version != 5 {
		return
	}

	// Send "no authentication required"
	clientConn.Write([]byte{5, 0})

	// Read request
	n, err = clientConn.Read(buf)
	if err != nil || n < 7 {
		return
	}

	cmd := buf[1]
	if cmd != 1 { // Only support CONNECT
		clientConn.Write([]byte{5, 7, 0, 1, 0, 0, 0, 0, 0, 0})
		return
	}

	atyp := buf[3]
	var host string
	var port uint16

	switch atyp {
	case 1: // IPv4
		host = fmt.Sprintf("%d.%d.%d.%d", buf[4], buf[5], buf[6], buf[7])
		port = uint16(buf[8])<<8 | uint16(buf[9])
	case 3: // Domain name
		domainLen := int(buf[4])
		host = string(buf[5 : 5+domainLen])
		port = uint16(buf[5+domainLen])<<8 | uint16(buf[6+domainLen])
	case 4: // IPv6
		// Not implemented
		clientConn.Write([]byte{5, 8, 0, 1, 0, 0, 0, 0, 0, 0})
		return
	default:
		clientConn.Write([]byte{5, 8, 0, 1, 0, 0, 0, 0, 0, 0})
		return
	}

	target := fmt.Sprintf("%s:%d", host, port)

	// Check if blocked
	if s.config.IsBlocked(host) {
		clientConn.Write([]byte{5, 2, 0, 1, 0, 0, 0, 0, 0, 0})
		log.Printf("Blocked SOCKS5 request to %s", target)
		return
	}

	// Connect to remote
	remoteConn, err := net.DialTimeout("tcp", target, time.Duration(s.config.Timeout)*time.Second)
	if err != nil {
		clientConn.Write([]byte{5, 5, 0, 1, 0, 0, 0, 0, 0, 0})
		log.Printf("SOCKS5 connection failed to %s: %v", target, err)
		return
	}
	defer remoteConn.Close()

	// Send success
	clientConn.Write([]byte{5, 0, 0, 1, 0, 0, 0, 0, 0, 0})
	log.Printf("SOCKS5: %s", target)

	// Transfer data
	s.transfer(clientConn, remoteConn)
}
