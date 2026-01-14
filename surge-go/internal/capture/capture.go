package capture

import (
	"sync"
	"time"
)

// Request represents a captured request/connection
type Request struct {
	ID            string    `json:"id"`
	URL           string    `json:"url"`      // host:port for TCP
	Method        string    `json:"method"`   // CONNECT, TCP, UDP
	StatusCode    int       `json:"status"`   // 0 for TCP
	Duration      float64   `json:"duration"` // Seconds
	Timestamp     time.Time `json:"timestamp"`
	Policy        string    `json:"policy"`
	Rule          string    `json:"rule"`
	SourceIP      string    `json:"source_ip"`
	UploadBytes   uint64    `json:"upload"`
	DownloadBytes uint64    `json:"download"`
	Failed        bool      `json:"failed"` // If connection failed
	Notes         string    `json:"notes"`
}

// Store manages captured requests in a ring buffer
type Store struct {
	mu       sync.RWMutex
	requests []*Request
	maxSize  int
}

// NewStore creates a new capture store
func NewStore(size int) *Store {
	if size <= 0 {
		size = 1000
	}
	return &Store{
		requests: make([]*Request, 0, size),
		maxSize:  size,
	}
}

// Add adds a request to the store
func (s *Store) Add(req *Request) {
	s.mu.Lock()
	defer s.mu.Unlock()

	// If full, remove oldest (index 0)
	if len(s.requests) >= s.maxSize {
		s.requests = s.requests[1:]
	}
	s.requests = append(s.requests, req)
}

// GetAll returns all requests
func (s *Store) GetAll() []*Request {
	s.mu.RLock()
	defer s.mu.RUnlock()

	// Return a copy to avoid race conditions
	result := make([]*Request, len(s.requests))
	copy(result, s.requests)
	return result
}

// Clear clears the store
func (s *Store) Clear() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.requests = make([]*Request, 0, s.maxSize)
}
