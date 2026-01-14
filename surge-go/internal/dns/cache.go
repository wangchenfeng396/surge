package dns

import (
	"net"
	"sync"
	"sync/atomic"
	"time"
)

type cacheEntry struct {
	ips       []net.IP
	expiresAt time.Time
}

// Cache implements a simple DNS cache with TTL
type Cache struct {
	entries map[string]*cacheEntry
	mu      sync.RWMutex
	// Stats
	hits   int64
	misses int64

	ttl time.Duration
}

// NewCache creates a new DNS cache
func NewCache(ttl time.Duration) *Cache {
	if ttl == 0 {
		ttl = 10 * time.Minute
	}
	c := &Cache{
		entries: make(map[string]*cacheEntry),
		ttl:     ttl,
	}
	go c.cleanup()
	return c
}

// Get retrieves IPs from cache
func (c *Cache) Get(host string) []net.IP {
	c.mu.RLock()
	entry, ok := c.entries[host]
	c.mu.RUnlock()

	if !ok {
		atomic.AddInt64(&c.misses, 1)
		return nil
	}

	if time.Now().After(entry.expiresAt) {
		atomic.AddInt64(&c.misses, 1)
		return nil
	}

	atomic.AddInt64(&c.hits, 1)
	return entry.ips
}

// Set adds IPs to cache
func (c *Cache) Set(host string, ips []net.IP) {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.entries[host] = &cacheEntry{
		ips:       ips,
		expiresAt: time.Now().Add(c.ttl),
	}
}

// Stats returns hit and miss counts
func (c *Cache) Stats() (int64, int64) {
	return atomic.LoadInt64(&c.hits), atomic.LoadInt64(&c.misses)
}

// Stats Returns checks
// Wait, I should import sync/atomic and use it.

// cleanup removes expired entries periodically
func (c *Cache) cleanup() {
	ticker := time.NewTicker(time.Minute)
	defer ticker.Stop()

	for range ticker.C {
		c.mu.Lock()
		now := time.Now()
		for host, entry := range c.entries {
			if now.After(entry.expiresAt) {
				delete(c.entries, host)
			}
		}
		c.mu.Unlock()
	}
}
