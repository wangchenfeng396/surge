package server

import (
	"bufio"
	"crypto/tls"
	"fmt"
	"io"
	"net"
	"net/http"
	"testing"
	"time"

	"github.com/surge-proxy/surge-go/internal/rewrite"
)

type mockRewriter struct{}

func (m *mockRewriter) Rewrite(urlStr string) (string, rewrite.RewriteAction) {
	if urlStr == "http://example.com/rewrite" {
		return "http://example.com/rewritten", rewrite.ActionRedirect302
	}
	return urlStr, rewrite.ActionNone
}

type mockMITM struct {
	intercepted []string
}

func (m *mockMITM) ShouldIntercept(host string) bool {
	if host == "intercept.com:443" || host == "intercept.com" {
		m.intercepted = append(m.intercepted, host)
		return true
	}
	return false
}

func (m *mockMITM) GetCertificate(hello *tls.ClientHelloInfo) (*tls.Certificate, error) {
	return nil, fmt.Errorf("mock GetCertificate not implemented")
}

func TestHTTPServer_Rewrite(t *testing.T) {
	// Setup server
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("Failed to listen: %v", err)
	}
	port := ln.Addr().(*net.TCPAddr).Port
	ln.Close() // Close to let server listen

	addr := fmt.Sprintf("127.0.0.1:%d", port)

	rewriter := &mockRewriter{}
	server := NewHTTPServer(addr, nil, rewriter, nil, nil)

	go server.Start()
	defer server.Stop()
	time.Sleep(100 * time.Millisecond)

	// Send request
	conn, err := net.Dial("tcp", addr)
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer conn.Close()

	req, _ := http.NewRequest("GET", "http://example.com/rewrite", nil)
	// Use WriteProxy to ensure absolute URI is sent
	req.WriteProxy(conn)

	// Read response
	resp, err := http.ReadResponse(bufio.NewReader(conn), req)
	if err != nil {
		t.Fatalf("Failed to read response: %v", err)
	}

	if resp.StatusCode != 302 {
		t.Errorf("Expected 302, got %d", resp.StatusCode)
	}
	if loc := resp.Header.Get("Location"); loc != "http://example.com/rewritten" {
		t.Errorf("Expected Location http://example.com/rewritten, got %s", loc)
	}
}

func TestHTTPServer_MITM(t *testing.T) {
	// Setup server
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("Failed to listen: %v", err)
	}
	port := ln.Addr().(*net.TCPAddr).Port
	ln.Close()

	addr := fmt.Sprintf("127.0.0.1:%d", port)

	mitm := &mockMITM{}
	server := NewHTTPServer(addr, nil, nil, nil, mitm)

	go server.Start()
	defer server.Stop()
	time.Sleep(100 * time.Millisecond)

	// Send CONNECT request
	conn, err := net.Dial("tcp", addr)
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer conn.Close()

	fmt.Fprintf(conn, "CONNECT intercept.com:443 HTTP/1.1\r\nHost: intercept.com:443\r\n\r\n")

	// Server should accept and maybe log or fail connection since we didn't implement full MITM handler
	// But ShouldIntercept should be called.
	time.Sleep(100 * time.Millisecond)

	if len(mitm.intercepted) == 0 {
		t.Error("MITM ShouldIntercept was not called")
	}
}

type mockBodyRewriter struct{}

func (m *mockBodyRewriter) RewriteResponse(urlStr string, body []byte) []byte {
	return []byte("rewritten body")
}

func TestHTTPServer_BodyRewrite(t *testing.T) {
	// Setup server
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("Failed to listen: %v", err)
	}
	port := ln.Addr().(*net.TCPAddr).Port
	ln.Close()

	addr := fmt.Sprintf("127.0.0.1:%d", port)

	bodyRewriter := &mockBodyRewriter{}
	server := NewHTTPServer(addr, nil, nil, bodyRewriter, nil)

	go server.Start()
	defer server.Stop()
	time.Sleep(100 * time.Millisecond)

	// Mock upstream server that returns "original body"
	upstreamLn, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("Failed to listen upstream: %v", err)
	}
	defer upstreamLn.Close()
	upstreamPort := upstreamLn.Addr().(*net.TCPAddr).Port

	go func() {
		conn, err := upstreamLn.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		rd := bufio.NewReader(conn)
		req, err := http.ReadRequest(rd)
		if err == nil {
			// Respond
			resp := "HTTP/1.1 200 OK\r\nContent-Length: 13\r\n\r\noriginal body"
			conn.Write([]byte(resp))
			// consume body if any?
			_ = req
		}
	}()

	// Connect via proxy
	conn, err := net.Dial("tcp", addr)
	if err != nil {
		t.Fatalf("Failed to connect: %v", err)
	}
	defer conn.Close()

	targetURL := fmt.Sprintf("http://127.0.0.1:%d/test", upstreamPort)
	req, _ := http.NewRequest("GET", targetURL, nil)
	req.WriteProxy(conn)

	// Read response
	resp, err := http.ReadResponse(bufio.NewReader(conn), req)
	if err != nil {
		t.Fatalf("Failed to read response: %v", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if string(body) != "rewritten body" {
		t.Errorf("Expected 'rewritten body', got '%s'", string(body))
	}
}
