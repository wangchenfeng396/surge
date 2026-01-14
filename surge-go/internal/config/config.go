package config

import (
	"encoding/json"
	"os"
	"sync"
)

// Config represents the proxy server configuration
type Config struct {
	Port           int      `json:"port"`
	Host           string   `json:"host"`
	SOCKS5Port     int      `json:"socks5_port"`
	APIPort        int      `json:"api_port"`
	BufferSize     int      `json:"buffer_size"`
	Timeout        int      `json:"timeout"`
	BlockedDomains []string `json:"blocked_domains"`
	DirectDomains  []string `json:"direct_domains"`
	Rules          []Rule   `json:"rules"`

	mu sync.RWMutex
}

// Rule represents a proxy rule
type Rule struct {
	Type    string `json:"type"`    // DOMAIN-SUFFIX, DOMAIN-KEYWORD, IP-CIDR, etc.
	Pattern string `json:"pattern"` // Pattern to match
	Action  string `json:"action"`  // DIRECT, PROXY, REJECT
	Policy  string `json:"policy"`  // Policy name (optional)
}

// DefaultConfig returns default configuration
func DefaultConfig() *Config {
	return &Config{
		Port:           8888,
		Host:           "127.0.0.1",
		SOCKS5Port:     1080,
		APIPort:        9090,
		BufferSize:     32768,
		Timeout:        30,
		BlockedDomains: []string{},
		DirectDomains:  []string{"localhost", "127.0.0.1"},
		Rules:          []Rule{},
	}
}

// LoadConfig loads configuration from file
func LoadConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return DefaultConfig(), nil
	}

	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}

	return &cfg, nil
}

// SaveConfig saves configuration to file
func (c *Config) SaveConfig(path string) error {
	c.mu.RLock()
	defer c.mu.RUnlock()

	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(path, data, 0644)
}

// IsBlocked checks if a domain is blocked
func (c *Config) IsBlocked(host string) bool {
	c.mu.RLock()
	defer c.mu.RUnlock()

	for _, domain := range c.BlockedDomains {
		if contains(host, domain) {
			return true
		}
	}
	return false
}

// IsDirect checks if a domain should use direct connection
func (c *Config) IsDirect(host string) bool {
	c.mu.RLock()
	defer c.mu.RUnlock()

	for _, domain := range c.DirectDomains {
		if contains(host, domain) {
			return true
		}
	}
	return false
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr ||
		s[len(s)-len(substr):] == substr ||
		s[:len(substr)] == substr)
}
