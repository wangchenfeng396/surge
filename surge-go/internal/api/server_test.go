package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/surge-proxy/surge-go/internal/config"
	"github.com/surge-proxy/surge-go/internal/engine"
)

func newTestServer() *Server {
	cfg := config.NewSurgeConfig()
	eng := engine.NewEngine(cfg)
	return NewServer(eng, "test.conf")
}

func TestServer_HandleHealth(t *testing.T) {
	server := newTestServer()

	req := httptest.NewRequest("GET", "/api/health", nil)
	w := httptest.NewRecorder()

	server.router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var response map[string]string
	err := json.NewDecoder(w.Body).Decode(&response)
	if err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if response["status"] != "ok" {
		t.Errorf("Expected status 'ok', got '%s'", response["status"])
	}
}

func TestServer_HandleSystemProxyStatus(t *testing.T) {
	server := newTestServer()

	req := httptest.NewRequest("GET", "/api/system-proxy/status", nil)
	w := httptest.NewRecorder()

	server.router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var response map[string]interface{}
	err := json.NewDecoder(w.Body).Decode(&response)
	if err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if _, ok := response["enabled"]; !ok {
		t.Error("Expected 'enabled' field in response")
	}

	if _, ok := response["port"]; !ok {
		t.Error("Expected 'port' field in response")
	}
}

func TestServer_HandleTUNStatus(t *testing.T) {
	server := newTestServer()

	req := httptest.NewRequest("GET", "/api/tun/status", nil)
	w := httptest.NewRecorder()

	server.router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("Expected status 200, got %d", w.Code)
	}

	var response map[string]interface{}
	err := json.NewDecoder(w.Body).Decode(&response)
	if err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if _, ok := response["enabled"]; !ok {
		t.Error("Expected 'enabled' field in response")
	}
}

func TestServer_CORSMiddleware(t *testing.T) {
	server := newTestServer()

	// Test OPTIONS request
	req := httptest.NewRequest("OPTIONS", "/api/health", nil)
	req.Header.Set("Origin", "http://localhost:3000")
	w := httptest.NewRecorder()

	// Manually wrap for testing as Start() does
	handler := CORSMiddleware(server.router)
	handler.ServeHTTP(w, req)

	// Check CORS headers
	if w.Header().Get("Access-Control-Allow-Origin") == "" {
		t.Error("Expected Access-Control-Allow-Origin header")
	}
}

func TestServer_InvalidJSON(t *testing.T) {
	server := newTestServer()

	// Send invalid JSON
	req := httptest.NewRequest("POST", "/api/config/proxies", bytes.NewBufferString("invalid json"))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	server.router.ServeHTTP(w, req)

	if w.Code == http.StatusOK {
		t.Error("Expected error status for invalid JSON")
	}
}

func TestServer_NotFoundRoute(t *testing.T) {
	server := newTestServer()

	req := httptest.NewRequest("GET", "/api/nonexistent", nil)
	w := httptest.NewRecorder()

	server.router.ServeHTTP(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("Expected status 404, got %d", w.Code)
	}
}

func TestServer_HandleRuleMatch(t *testing.T) {
	server := newTestServer()

	// Engine RuleEngine is nil in default test server, so we expect error or need to init it.
	// NewEngine initializes map, but sub-components are usually nil or empty struct.
	// MatchRule checks for nil RuleEngine.
	// Let's verify it handles the error gracefully or modify newTestServer to mock RuleEngine.

	reqBody := `{"url": "https://google.com", "source_ip": "192.168.1.5", "process": "chrome"}`
	req := httptest.NewRequest("POST", "/api/rules/match", bytes.NewBufferString(reqBody))
	w := httptest.NewRecorder()

	server.router.ServeHTTP(w, req)

	// Since RuleEngine is not initialized in NewEngine(cfg) by default (it's nil field),
	// MatchRule returns error "Rule engine not initialized".
	// Handler returns 500.
	if w.Code != http.StatusInternalServerError {
		t.Errorf("Expected status 500 (since engine not fully ready), got %d", w.Code)
	}
}

func TestServer_HandleDNSQuery(t *testing.T) {
	server := newTestServer()

	req := httptest.NewRequest("GET", "/api/dns/query?host=google.com", nil)
	w := httptest.NewRecorder()

	server.router.ServeHTTP(w, req)

	// DNSManager is nil, so returns 500
	if w.Code != http.StatusInternalServerError {
		t.Errorf("Expected status 500, got %d", w.Code)
	}
}
