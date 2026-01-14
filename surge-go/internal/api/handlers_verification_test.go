package api

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/surge-proxy/surge-go/internal/config"
	"github.com/surge-proxy/surge-go/internal/engine"
)

type mockTransport struct{}

func (m *mockTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	time.Sleep(10 * time.Millisecond)
	return &http.Response{
		StatusCode: 200,
		Body:       io.NopCloser(strings.NewReader("OK")),
	}, nil
}

func TestHandleTestProxyLive_Optimization(t *testing.T) {
	cfg := &config.SurgeConfig{
		General: &config.GeneralConfig{},
	}
	e := engine.NewEngine(cfg)
	// Create Server manually to avoid config loading issues in test
	s := &Server{
		engine: e,
		testClient: &http.Client{
			Transport: &mockTransport{},
		},
	}

	reqBody := `{"name":"test","url":"http://example.com"}`
	req := httptest.NewRequest("POST", "/api/proxy/test-live", strings.NewReader(reqBody))
	w := httptest.NewRecorder()

	s.handleTestProxyLive(w, req)

	resp := w.Result()
	if resp.StatusCode != 200 {
		t.Fatalf("Expected 200, got %d", resp.StatusCode)
	}

	var data map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		t.Fatalf("Failed to decode response: %v", err)
	}

	if _, ok := data["timing"]; !ok {
		t.Error("Response missing 'timing' field")
	}

	timing, ok := data["timing"].(map[string]interface{})
	if !ok {
		t.Error("'timing' field is not a map")
	} else {
		if _, ok := timing["total"]; !ok {
			t.Error("timing missing 'total'")
		}
		// connect/ttfb might be missing if 0?
		t.Logf("Timing: %+v", timing)
	}
}
