// Package geoip provides GeoIP database functionality
package geoip

import (
	"fmt"
	"net"
	"sync"
)

// Database represents a GeoIP database
type Database struct {
	mu       sync.RWMutex
	data     map[string]string // IP range -> Country code
	loaded   bool
	filePath string
}

// NewDatabase creates a new GeoIP database
func NewDatabase(filePath string) *Database {
	return &Database{
		data:     make(map[string]string),
		loaded:   false,
		filePath: filePath,
	}
}

// Load loads the GeoIP database from file
func (db *Database) Load() error {
	db.mu.Lock()
	defer db.mu.Unlock()

	// TODO: Implement actual MaxMind GeoIP2 database loading
	// For now, add some sample data
	db.data["1.0.0.0/8"] = "CN"
	db.data["8.8.8.0/24"] = "US"
	db.data["223.0.0.0/8"] = "CN"

	db.loaded = true
	return nil
}

// Lookup looks up the country code for an IP address
func (db *Database) Lookup(ip string) (string, error) {
	db.mu.RLock()
	defer db.mu.RUnlock()

	if !db.loaded {
		return "", fmt.Errorf("database not loaded")
	}

	parsedIP := net.ParseIP(ip)
	if parsedIP == nil {
		return "", fmt.Errorf("invalid IP address: %s", ip)
	}

	// Check each CIDR range
	for cidr, country := range db.data {
		_, ipNet, err := net.ParseCIDR(cidr)
		if err != nil {
			continue
		}

		if ipNet.Contains(parsedIP) {
			return country, nil
		}
	}

	return "UNKNOWN", nil
}

// IsLoaded returns whether the database is loaded
func (db *Database) IsLoaded() bool {
	db.mu.RLock()
	defer db.mu.RUnlock()
	return db.loaded
}

// Update updates the GeoIP database from a URL
func (db *Database) Update(url string) error {
	// TODO: Implement downloading and updating from URL
	// This would download the MaxMind GeoIP2 database
	return fmt.Errorf("not implemented")
}
