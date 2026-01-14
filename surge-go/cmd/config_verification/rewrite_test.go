package main_test

import (
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"testing"
	"time"

	"github.com/surge-proxy/surge-go/internal/config"
	"github.com/surge-proxy/surge-go/internal/engine"
	"github.com/surge-proxy/surge-go/internal/server"
)

func TestRewrites(t *testing.T) {
	// 1. Start Mock Target Server
	mockListener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("Failed to listen for mock server: %v", err)
	}
	defer mockListener.Close()
	mockAddr := mockListener.Addr().String()

	go func() {
		http.Serve(mockListener, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Path == "/body" {
				w.Write([]byte("Hello World"))
				return
			}
			w.WriteHeader(200)
		}))
	}()

	// 2. Create Config
	cfg := config.NewSurgeConfig()
	cfg.General = &config.GeneralConfig{
		LogLevel: "info",
	}
	cfg.URLRewrites = []*config.URLRewriteConfig{
		{
			Regex:       "^http://www.google.cn",
			Replacement: "https://www.google.com",
			Type:        "302",
		},
		{
			Regex:       "^http://reject.com",
			Replacement: "",
			Type:        "reject",
		},
	}
	// http-response regex match replacement
	// ^http://127.0.0.1:\d+/body World Surge
	cfg.BodyRewrites = []*config.BodyRewriteConfig{
		{
			Type:           "http-response",
			URLRegex:       fmt.Sprintf("^http://%s/body", mockAddr),
			ReplacementOld: "World",
			ReplacementNew: "Surge",
		},
	}

	// 3. Start Engine
	eng := engine.NewEngine(cfg)
	if err := eng.Start(); err != nil {
		t.Fatalf("Failed to start engine: %v", err)
	}
	defer eng.Stop()

	// 4. Start HTTP Server
	proxyPort := 18888
	proxyAddr := fmt.Sprintf("127.0.0.1:%d", proxyPort)

	var rewriter server.Rewriter
	if eng.URLRewriter != nil {
		rewriter = eng.URLRewriter
	}
	var bodyRewriter server.BodyRewriter
	if eng.BodyRewriter != nil {
		bodyRewriter = eng.BodyRewriter
	}

	srv := server.NewHTTPServer(proxyAddr, eng, rewriter, bodyRewriter, nil)
	go func() {
		if err := srv.Start(); err != nil {
			// t.Logf("Server error: %v", err)
		}
	}()
	defer srv.Shutdown(context.Background())

	time.Sleep(200 * time.Millisecond)

	// 5. Test Client
	proxyURL, _ := url.Parse(fmt.Sprintf("http://%s", proxyAddr))
	client := &http.Client{
		Transport: &http.Transport{
			Proxy: http.ProxyURL(proxyURL),
		},
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}

	t.Run("Test URL Rewrite 302", func(t *testing.T) {
		resp, err := client.Get("http://www.google.cn/")
		if err != nil {
			t.Fatalf("Request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 302 {
			t.Errorf("Expected 302, got %d", resp.StatusCode)
		}
		loc := resp.Header.Get("Location")
		if loc != "https://www.google.com/" {
			t.Errorf("Expected Location https://www.google.com/, got %s", loc)
		}
	})

	t.Run("Test URL Reject", func(t *testing.T) {
		resp, err := client.Get("http://reject.com/")
		if err != nil {
			t.Fatalf("Request failed: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != 502 {
			t.Errorf("Expected 502, got %d", resp.StatusCode)
		}
	})

	t.Run("Test Body Rewrite", func(t *testing.T) {
		targetURL := fmt.Sprintf("http://%s/body", mockAddr)
		resp, err := client.Get(targetURL)
		if err != nil {
			t.Fatalf("Request failed: %v", err)
		}
		defer resp.Body.Close()

		body, _ := io.ReadAll(resp.Body)
		if string(body) != "Hello Surge" {
			t.Errorf("Expected 'Hello Surge', got '%s'", string(body))
		}
	})
}
