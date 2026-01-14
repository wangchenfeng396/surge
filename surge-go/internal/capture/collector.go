// Package capture provides HTTP request/response capture functionality
package capture

import (
	"bytes"
	"io"
	"net/http"
	"sync"
	"time"
)

// CapturedRequest represents a captured HTTP request/response pair
type CapturedRequest struct {
	ID              string              `json:"id"`
	Method          string              `json:"method"`
	URL             string              `json:"url"`
	StatusCode      int                 `json:"status_code"`
	RequestTime     time.Time           `json:"request_time"`
	ResponseTime    time.Time           `json:"response_time"`
	Duration        int64               `json:"duration"` // milliseconds
	RequestSize     int64               `json:"request_size"`
	ResponseSize    int64               `json:"response_size"`
	RequestHeaders  map[string][]string `json:"request_headers"`
	ResponseHeaders map[string][]string `json:"response_headers"`
	RequestBody     string              `json:"request_body,omitempty"`
	ResponseBody    string              `json:"response_body,omitempty"`
	RemoteAddr      string              `json:"remote_addr"`
	Process         string              `json:"process,omitempty"`
}

// Collector manages captured requests
type Collector struct {
	mu       sync.RWMutex
	enabled  bool
	requests []CapturedRequest
	maxSize  int
}

// NewCollector creates a new capture collector
func NewCollector(maxSize int) *Collector {
	return &Collector{
		enabled:  false,
		requests: make([]CapturedRequest, 0),
		maxSize:  maxSize,
	}
}

// Enable enables request capture
func (c *Collector) Enable() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.enabled = true
}

// Disable disables request capture
func (c *Collector) Disable() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.enabled = false
}

// IsEnabled returns whether capture is enabled
func (c *Collector) IsEnabled() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.enabled
}

// Capture captures a request/response pair
func (c *Collector) Capture(req *http.Request, resp *http.Response, duration time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !c.enabled {
		return
	}

	captured := CapturedRequest{
		ID:              generateID(),
		Method:          req.Method,
		URL:             req.URL.String(),
		StatusCode:      resp.StatusCode,
		RequestTime:     time.Now().Add(-duration),
		ResponseTime:    time.Now(),
		Duration:        duration.Milliseconds(),
		RequestHeaders:  cloneHeaders(req.Header),
		ResponseHeaders: cloneHeaders(resp.Header),
		RemoteAddr:      req.RemoteAddr,
	}

	// Capture request body if present
	if req.Body != nil {
		bodyBytes, _ := io.ReadAll(req.Body)
		captured.RequestBody = string(bodyBytes)
		captured.RequestSize = int64(len(bodyBytes))
		req.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
	}

	// Capture response body if present
	if resp.Body != nil {
		bodyBytes, _ := io.ReadAll(resp.Body)
		captured.ResponseBody = string(bodyBytes)
		captured.ResponseSize = int64(len(bodyBytes))
		resp.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))
	}

	// Add to collection
	c.requests = append(c.requests, captured)

	// Trim if exceeds max size
	if len(c.requests) > c.maxSize {
		c.requests = c.requests[len(c.requests)-c.maxSize:]
	}
}

// GetAll returns all captured requests
func (c *Collector) GetAll() []CapturedRequest {
	c.mu.RLock()
	defer c.mu.RUnlock()

	result := make([]CapturedRequest, len(c.requests))
	copy(result, c.requests)
	return result
}

// Clear clears all captured requests
func (c *Collector) Clear() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.requests = make([]CapturedRequest, 0)
}

// Helper functions

func generateID() string {
	return time.Now().Format("20060102150405.000000")
}

func cloneHeaders(headers http.Header) map[string][]string {
	result := make(map[string][]string)
	for k, v := range headers {
		result[k] = append([]string{}, v...)
	}
	return result
}
