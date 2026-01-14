package geoip

import (
	"errors"
	"net"
	"sync"

	"github.com/oschwald/maxminddb-golang"
)

// Global DB instance
var (
	instance *MaxMindDB
	mu       sync.RWMutex
)

// CountryResult is the record struct for decoding MMDB
type CountryResult struct {
	Country struct {
		IsoCode string `maxminddb:"iso_code"`
	} `maxminddb:"country"`
}

// MaxMindDB wraps the maxminddb reader
type MaxMindDB struct {
	reader *maxminddb.Reader
	path   string
}

// Init initializes the global GeoIP database
func Init(path string) error {
	mu.Lock()
	defer mu.Unlock()

	if instance != nil {
		instance.Close()
	}

	reader, err := maxminddb.Open(path)
	if err != nil {
		return err
	}

	instance = &MaxMindDB{
		reader: reader,
		path:   path,
	}
	return nil
}

// LookupCountry returns the ISO country code for the given IP
func LookupCountry(ip net.IP) (string, error) {
	mu.RLock()
	defer mu.RUnlock()

	if instance == nil || instance.reader == nil {
		return "", errors.New("GeoIP database not initialized")
	}

	var result CountryResult
	if err := instance.reader.Lookup(ip, &result); err != nil {
		return "", err
	}

	return result.Country.IsoCode, nil
}

// Close closes the database
func (db *MaxMindDB) Close() error {
	if db.reader != nil {
		return db.reader.Close()
	}
	return nil
}

// Close closes the global database
func Close() {
	mu.Lock()
	defer mu.Unlock()
	if instance != nil {
		instance.Close()
		instance = nil
	}
}

// IsInitialized checks if DB is ready
func IsInitialized() bool {
	mu.RLock()
	defer mu.RUnlock()
	return instance != nil
}
