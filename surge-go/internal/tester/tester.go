// Package tester provides proxy latency testing functionality
package tester

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"time"
)

// ProxyTester tests proxy server latency
type ProxyTester struct {
	timeout time.Duration
}

// NewProxyTester creates a new proxy tester
func NewProxyTester(timeout time.Duration) *ProxyTester {
	return &ProxyTester{
		timeout: timeout,
	}
}

// TestResult represents a proxy test result
type TestResult struct {
	Success  bool      `json:"success"`
	Latency  int64     `json:"latency"` // milliseconds
	Error    string    `json:"error,omitempty"`
	TestTime time.Time `json:"test_time"`
}

// TestHTTP tests an HTTP proxy
func (t *ProxyTester) TestHTTP(proxyURL, testURL string) TestResult {
	start := time.Now()

	// Parse proxy URL
	proxy, err := url.Parse(proxyURL)
	if err != nil {
		return TestResult{
			Success:  false,
			Error:    fmt.Sprintf("Invalid proxy URL: %v", err),
			TestTime: time.Now(),
		}
	}

	// Create HTTP client with proxy
	client := &http.Client{
		Transport: &http.Transport{
			Proxy: http.ProxyURL(proxy),
		},
		Timeout: t.timeout,
	}

	// Make request
	ctx, cancel := context.WithTimeout(context.Background(), t.timeout)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "GET", testURL, nil)
	if err != nil {
		return TestResult{
			Success:  false,
			Error:    fmt.Sprintf("Failed to create request: %v", err),
			TestTime: time.Now(),
		}
	}

	resp, err := client.Do(req)
	if err != nil {
		return TestResult{
			Success:  false,
			Error:    fmt.Sprintf("Request failed: %v", err),
			TestTime: time.Now(),
		}
	}
	defer resp.Body.Close()

	latency := time.Since(start).Milliseconds()

	return TestResult{
		Success:  resp.StatusCode >= 200 && resp.StatusCode < 400,
		Latency:  latency,
		TestTime: time.Now(),
	}
}

// TestSOCKS5 tests a SOCKS5 proxy
func (t *ProxyTester) TestSOCKS5(proxyAddr, testHost string, testPort int) TestResult {
	start := time.Now()

	// Connect to SOCKS5 proxy
	conn, err := net.DialTimeout("tcp", proxyAddr, t.timeout)
	if err != nil {
		return TestResult{
			Success:  false,
			Error:    fmt.Sprintf("Failed to connect to proxy: %v", err),
			TestTime: time.Now(),
		}
	}
	defer conn.Close()

	// Set deadline
	conn.SetDeadline(time.Now().Add(t.timeout))

	// SOCKS5 handshake
	// Send greeting
	_, err = conn.Write([]byte{0x05, 0x01, 0x00}) // Version 5, 1 method, no auth
	if err != nil {
		return TestResult{
			Success:  false,
			Error:    fmt.Sprintf("Handshake failed: %v", err),
			TestTime: time.Now(),
		}
	}

	// Read response
	buf := make([]byte, 2)
	_, err = conn.Read(buf)
	if err != nil || buf[0] != 0x05 || buf[1] != 0x00 {
		return TestResult{
			Success:  false,
			Error:    "SOCKS5 handshake failed",
			TestTime: time.Now(),
		}
	}

	// Send connect request
	request := []byte{0x05, 0x01, 0x00, 0x03} // Version, Connect, Reserved, Domain
	request = append(request, byte(len(testHost)))
	request = append(request, []byte(testHost)...)
	request = append(request, byte(testPort>>8), byte(testPort&0xff))

	_, err = conn.Write(request)
	if err != nil {
		return TestResult{
			Success:  false,
			Error:    fmt.Sprintf("Connect request failed: %v", err),
			TestTime: time.Now(),
		}
	}

	// Read response
	response := make([]byte, 10)
	_, err = conn.Read(response)
	if err != nil || response[1] != 0x00 {
		return TestResult{
			Success:  false,
			Error:    "SOCKS5 connect failed",
			TestTime: time.Now(),
		}
	}

	latency := time.Since(start).Milliseconds()

	return TestResult{
		Success:  true,
		Latency:  latency,
		TestTime: time.Now(),
	}
}

// TestDirect tests direct connection (no proxy)
func (t *ProxyTester) TestDirect(testURL string) TestResult {
	start := time.Now()

	client := &http.Client{
		Timeout: t.timeout,
	}

	ctx, cancel := context.WithTimeout(context.Background(), t.timeout)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "GET", testURL, nil)
	if err != nil {
		return TestResult{
			Success:  false,
			Error:    fmt.Sprintf("Failed to create request: %v", err),
			TestTime: time.Now(),
		}
	}

	resp, err := client.Do(req)
	if err != nil {
		return TestResult{
			Success:  false,
			Error:    fmt.Sprintf("Request failed: %v", err),
			TestTime: time.Now(),
		}
	}
	defer resp.Body.Close()

	latency := time.Since(start).Milliseconds()

	return TestResult{
		Success:  resp.StatusCode >= 200 && resp.StatusCode < 400,
		Latency:  latency,
		TestTime: time.Now(),
	}
}
