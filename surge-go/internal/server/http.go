package server

import (
	"bufio"
	"bytes"
	"context"
	"crypto/tls"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/surge-proxy/surge-go/internal/protocol"
	"github.com/surge-proxy/surge-go/internal/rewrite"
)

// HTTPServer implements HTTP CONNECT proxy server
type HTTPServer struct {
	addr    string
	dialer  protocol.Dialer
	handler RequestHandler
	ln      net.Listener
	mu      sync.Mutex
	closed  bool
	wg      sync.WaitGroup

	// Advanced features
	rewriter     Rewriter
	bodyRewriter BodyRewriter
	mitmManager  MITM
}

// BodyRewriter interface
type BodyRewriter interface {
	RewriteResponse(urlStr string, body []byte) []byte
}

// Rewriter interface for URL modification
type Rewriter interface {
	Rewrite(urlStr string) (string, rewrite.RewriteAction)
}

// MITM interface for interception checks
type MITM interface {
	ShouldIntercept(host string) bool
	GetCertificate(hello *tls.ClientHelloInfo) (*tls.Certificate, error)
}

// RequestHandler handles proxy requests and returns appropriate dialer
type RequestHandler interface {
	// HandleRequest returns the dialer to use for this request
	// Returns nil to use direct connection
	HandleRequest(ctx context.Context, network, address, source string) protocol.Dialer
}

// NewHTTPServer creates a new HTTP proxy server
func NewHTTPServer(addr string, handler RequestHandler, rewriter Rewriter, bodyRewriter BodyRewriter, mitm MITM) *HTTPServer {
	return &HTTPServer{
		addr:         addr,
		handler:      handler,
		rewriter:     rewriter,
		bodyRewriter: bodyRewriter,
		mitmManager:  mitm,
	}
}

// NewHTTPServerWithDialer creates HTTP proxy server with a fixed dialer
func NewHTTPServerWithDialer(addr string, dialer protocol.Dialer) *HTTPServer {
	return &HTTPServer{
		addr:   addr,
		dialer: dialer,
	}
}

// rewriteAndWriteResponse applies body rewrite and writes response to writer
func (s *HTTPServer) rewriteAndWriteResponse(resp *http.Response, req *http.Request, w io.Writer, isMITM bool) error {
	if s.bodyRewriter != nil {
		// Read full body
		body, err := io.ReadAll(resp.Body)
		resp.Body.Close() // Close original body
		if err != nil {
			return err
		}

		// Rewrite
		// Is URL relative? If so, construct full URL for matching
		urlStr := req.URL.String() // Scheme/Host might be missing if not MITM or standard proxy
		if req.URL.Scheme == "" {
			if isMITM {
				urlStr = "https://" + req.Host + req.URL.Path
			} else {
				urlStr = "http://" + req.Host + req.URL.Path
			}
		}

		newBody := s.bodyRewriter.RewriteResponse(urlStr, body)

		// Replace body
		resp.Body = io.NopCloser(bytes.NewReader(newBody))
		resp.ContentLength = int64(len(newBody))
		resp.Header.Set("Content-Length", fmt.Sprintf("%d", len(newBody)))
	}

	return resp.Write(w)
}

// Start starts the HTTP proxy server
func (s *HTTPServer) Start() error {
	ln, err := net.Listen("tcp", s.addr)
	if err != nil {
		return fmt.Errorf("failed to listen on %s: %v", s.addr, err)
	}

	s.mu.Lock()
	s.ln = ln
	s.mu.Unlock()

	log.Printf("HTTP proxy server listening on %s", s.addr)

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

// Stop stops the HTTP proxy server
func (s *HTTPServer) Stop() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.closed = true
	if s.ln != nil {
		return s.ln.Close()
	}
	return nil
}

// Shutdown gracefully stops the server
func (s *HTTPServer) Shutdown(ctx context.Context) error {
	// Stop accepting
	s.Stop()

	// Wait for active
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
func (s *HTTPServer) Addr() string {
	return s.addr
}

// handleConnection handles a single HTTP proxy connection
func (s *HTTPServer) handleConnection(clientConn net.Conn) {
	log.Printf("HTTP: New connection from %s", clientConn.RemoteAddr())
	defer s.wg.Done()
	defer clientConn.Close()

	// Set read deadline for initial request
	clientConn.SetReadDeadline(time.Now().Add(30 * time.Second))

	// Read HTTP request
	reader := bufio.NewReader(clientConn)
	req, err := http.ReadRequest(reader)
	if err != nil {
		log.Printf("Failed to read request: %v", err)
		return
	}

	// Reset deadline
	clientConn.SetReadDeadline(time.Time{})

	// Handle CONNECT method (for HTTPS)
	if req.Method == http.MethodConnect {
		s.handleConnect(clientConn, req)
		return
	}

	// Handle regular HTTP requests
	s.handleHTTP(clientConn, req, reader)
}

// handleConnect handles HTTP CONNECT requests (for HTTPS tunneling)
func (s *HTTPServer) handleConnect(clientConn net.Conn, req *http.Request) {
	log.Printf("HTTP: Handling CONNECT for %s", req.Host)
	log.Printf("HTTP: Header: %v", req.Header)
	// Get target address
	host := req.Host
	if !strings.Contains(host, ":") {
		host = host + ":443"
	}

	// Check MITM
	shouldIntercept := s.mitmManager != nil && s.mitmManager.ShouldIntercept(host)
	log.Printf("HTTP: MITM check for %s: %v", host, shouldIntercept)
	if shouldIntercept {
		log.Printf("MITM Intercept: %s", host)
		// 1. Send 200 OK to establish tunnel
		clientConn.Write([]byte("HTTP/1.1 200 Connection Established\r\n\r\n"))

		// 2. Wrap client connection with TLS Server
		tlsConfig := &tls.Config{
			GetCertificate: s.mitmManager.GetCertificate,
			NextProtos:     []string{"http/1.1"}, // TODO: Support h2
		}
		tlsConn := tls.Server(clientConn, tlsConfig)
		// Perform handshake manually to catch errors early
		if err := tlsConn.Handshake(); err != nil {
			log.Printf("MITM Client Handshake error (Client <-> Proxy): %v", err)
			conn, _ := clientConn.(*net.TCPConn)
			if conn != nil {
				conn.SetLinger(0) // Reset connection on error
			}
			return
		}
		defer tlsConn.Close()
		log.Printf("MITM Client Handshake success for %s", host)

		// 3. Dial Target TLS
		// Need to ensure we dial TLS to target
		// Use empty context or propagate metadata?
		// CONNECT headers were on 'req' which is passed to handleConnect.
		// We should extract header earlier in handleConnect if we want it here.
		// Let's copy the logic.
		ctx := context.Background()
		if testName := req.Header.Get("X-Surge-Test-Proxy"); testName != "" {
			ctx = context.WithValue(ctx, "TestProxyName", testName)
		}

		targetDialer := s.getDialer(ctx, "tcp", host, clientConn.RemoteAddr().String())
		// We can't use standard DialContext here because we need TLS on top.
		// If the dialer returns a proxy conn, we need to wrap it in TLS if it's not already?
		// Usually dialer processes the "CONNECT" itself if it's a proxy.
		// If it's DIRECT, we get a TCP conn.
		// We need to wrap it in tls.Client.

		rawConn, err := targetDialer.DialContext(context.Background(), "tcp", host)
		if err != nil {
			log.Printf("MITM Dial Target error (Proxy <-> Target): %v", err)
			return
		}
		log.Printf("MITM Connected to target %s", host)

		targetTLS := tls.Client(rawConn, &tls.Config{
			InsecureSkipVerify: true, // TODO: Configurable
			ServerName:         strings.Split(host, ":")[0],
		})
		if err := targetTLS.Handshake(); err != nil {
			log.Printf("MITM Target Handshake error (Proxy <-> Target): %v", err)
			rawConn.Close()
			return
		}
		log.Printf("MITM Target TLS Handshake success for %s", host)
		defer targetTLS.Close()

		// 4. Process HTTP requests over the tunnel
		s.processHTTPPair(tlsConn, targetTLS, true)
		return
	}
	log.Printf("HTTP: Non-MITM tunnel for %s", host)

	// Parse X-Surge-Test-Proxy header from CONNECT request?
	// CONNECT requests usually don't have custom headers easily set by clients except Proxy-Authorization
	// However, standard Go client with ProxyConnectHeader splits them.
	// We should check req.Header.
	ctx := context.Background()
	if testName := req.Header.Get("X-Surge-Test-Proxy"); testName != "" {
		ctx = context.WithValue(ctx, "TestProxyName", testName)
	}

	// Get dialer for this request
	dialer := s.getDialer(ctx, "tcp", host, clientConn.RemoteAddr().String())

	// Connect to target
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	targetConn, err := dialer.DialContext(ctx, "tcp", host)
	if err != nil {
		log.Printf("Failed to connect to %s: %v", host, err)
		clientConn.Write([]byte("HTTP/1.1 502 Bad Gateway\r\n\r\n"))
		return
	}
	defer targetConn.Close()

	// Send 200 Connection Established
	_, err = clientConn.Write([]byte("HTTP/1.1 200 Connection Established\r\n\r\n"))
	if err != nil {
		log.Printf("Failed to send response: %v", err)
		return
	}

	// Start bidirectional copy
	s.relay(clientConn, targetConn)
}

// handleHTTP handles regular HTTP requests
func (s *HTTPServer) handleHTTP(clientConn net.Conn, req *http.Request, reader *bufio.Reader) {
	// Handle URL Rewrite
	if s.rewriter != nil {
		newURL, action := s.rewriter.Rewrite(req.URL.String())
		if action == rewrite.ActionRedirect302 {
			clientConn.Write([]byte(fmt.Sprintf("HTTP/1.1 302 Found\r\nLocation: %s\r\n\r\n", newURL)))
			return
		} else if action == rewrite.ActionRedirect307 {
			clientConn.Write([]byte(fmt.Sprintf("HTTP/1.1 307 Temporary Redirect\r\nLocation: %s\r\n\r\n", newURL)))
			return
		} else if action == rewrite.ActionReject {
			clientConn.Write([]byte("HTTP/1.1 502 Bad Gateway\r\n\r\n")) // Or 403
			return
		} else if action == rewrite.ActionNone && newURL != req.URL.String() {
			// Rewrite URL but continue (e.g. slight mod)
			// Need to parse back
			if newU, err := url.Parse(newURL); err == nil {
				req.URL = newU
				req.Host = newU.Host // Update Host header usually required
			}
		}
	}

	// Get target address
	host := req.Host
	if !strings.Contains(host, ":") {
		host = host + ":80"
	}

	// Parse X-Surge-Test-Proxy header
	ctx := context.Background()
	if testName := req.Header.Get("X-Surge-Test-Proxy"); testName != "" {
		ctx = context.WithValue(ctx, "TestProxyName", testName)
		// Clean up header so it's not sent to target
		req.Header.Del("X-Surge-Test-Proxy")
	}

	// Get dialer for this request
	dialer := s.getDialer(ctx, "tcp", host, clientConn.RemoteAddr().String())

	// Connect to target
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	targetConn, err := dialer.DialContext(ctx, "tcp", host)
	if err != nil {
		log.Printf("Failed to connect to %s: %v", host, err)
		clientConn.Write([]byte("HTTP/1.1 502 Bad Gateway\r\n\r\n"))
		return
	}
	defer targetConn.Close()

	// Write first request to target
	// We use writeRequest helper which applies rewrite again safely (idempotent if no change or consistent change)
	// Write first request to target
	// We use processRequestWithRewrite helper which applies rewrite again safely (idempotent if no change or consistent change)
	// Note: handleHTTP might have already applied rewrite, but applying again is safe for idempotent rules.
	// If it was a redirect, handleHTTP returned early. So here it's likely ActionNone or no match.
	handled, err := s.processRequestWithRewrite(req, targetConn, clientConn)
	if err != nil {
		log.Printf("Failed to write request: %v", err)
		return
	}
	if handled {
		return
	}

	// Start processing loop
	// We just read the first request manually. We wrote it.
	// Now we enter the loop for *subsequent* requests OR responses?
	// Wait, processHTTPPair reading loop starts by reading request.
	// But we already read the first one.
	// We need to handle the RESPONSE for the first one.

	// Option A: Pass the first request to processHTTPPair?
	// Option B: Handle first response here, then enter loop?

	// Let's handle first response here.
	targetReader := bufio.NewReader(targetConn)
	resp, err := http.ReadResponse(targetReader, req)
	if err != nil {
		log.Printf("Failed to read header response: %v", err)
		return
	}
	if err := s.rewriteAndWriteResponse(resp, req, clientConn, false); err != nil {
		return
	}

	if !resp.Close && !req.Close {
		s.processHTTPPair(clientConn, targetConn, false)
	}
}

// getDialer returns the appropriate dialer for the request
func (s *HTTPServer) getDialer(ctx context.Context, network, address, source string) protocol.Dialer {
	// If handler is set, use it
	if s.handler != nil {
		if dialer := s.handler.HandleRequest(ctx, network, address, source); dialer != nil {
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
func (s *HTTPServer) relay(conn1, conn2 net.Conn) {
	var wg sync.WaitGroup
	wg.Add(2)

	// Copy from conn1 to conn2
	go func() {
		defer wg.Done()
		io.Copy(conn2, conn1)
		// Close write side to signal EOF
		if tcpConn, ok := conn2.(*net.TCPConn); ok {
			tcpConn.CloseWrite()
		}
	}()

	// Copy from conn2 to conn1
	go func() {
		defer wg.Done()
		io.Copy(conn1, conn2)
		// Close write side to signal EOF
		if tcpConn, ok := conn1.(*net.TCPConn); ok {
			tcpConn.CloseWrite()
		}
	}()

	wg.Wait()
}

// processRequestWithRewrite applies URL rewrite. If redirect/reject, writes response to client and returns true (handled).
// Otherwise writes request to target.
func (s *HTTPServer) processRequestWithRewrite(req *http.Request, targetConn io.Writer, clientConn io.Writer) (bool, error) {
	if s.rewriter != nil {
		newURL, action := s.rewriter.Rewrite(req.URL.String())

		if action == rewrite.ActionRedirect302 {
			clientConn.Write([]byte(fmt.Sprintf("HTTP/1.1 302 Found\r\nLocation: %s\r\n\r\n", newURL)))
			return true, nil
		} else if action == rewrite.ActionRedirect307 {
			clientConn.Write([]byte(fmt.Sprintf("HTTP/1.1 307 Temporary Redirect\r\nLocation: %s\r\n\r\n", newURL)))
			return true, nil
		} else if action == rewrite.ActionReject {
			clientConn.Write([]byte("HTTP/1.1 502 Bad Gateway\r\n\r\n"))
			return true, nil
		}

		// Modification
		if action == rewrite.ActionNone && newURL != req.URL.String() {
			if newU, err := url.Parse(newURL); err == nil {
				req.URL = newU
				req.Host = newU.Host
			}
		}
	}
	return false, req.Write(targetConn)
}

// processHTTPPair handles HTTP request/response loop between client and target
func (s *HTTPServer) processHTTPPair(clientConn, targetConn net.Conn, isMITM bool) {
	clientReader := bufio.NewReader(clientConn)
	targetReader := bufio.NewReader(targetConn)

	for {
		// 1. Read Request from Client
		clientConn.SetReadDeadline(time.Now().Add(60 * time.Second))
		req, err := http.ReadRequest(clientReader)
		if err != nil {
			return
		}
		clientConn.SetReadDeadline(time.Time{})

		if req.Header.Get("Upgrade") != "" {
			req.Write(targetConn)
			s.relay(clientConn, targetConn)
			return
		}

		if isMITM {
			req.URL.Scheme = "https"
			req.URL.Host = req.Host
		}

		// 3. Write Request to Target
		handled, err := s.processRequestWithRewrite(req, targetConn, clientConn)
		if err != nil {
			log.Printf("WriteReq err: %v", err)
			return
		}
		if handled {
			// If handled (e.g. redirected), we should continue to next request loop?
			// Or usually we are done with this request.
			continue
		}

		// 4. Read Response from Target
		targetConn.SetReadDeadline(time.Now().Add(60 * time.Second))
		resp, err := http.ReadResponse(targetReader, req)
		if err != nil {
			return
		}
		targetConn.SetReadDeadline(time.Time{})

		// 5. Body Rewrite
		if err := s.rewriteAndWriteResponse(resp, req, clientConn, isMITM); err != nil {
			return
		}

		if resp.Close || req.Close {
			return
		}
	}
}
