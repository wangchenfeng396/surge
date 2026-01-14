package geoip

import (
	"net"
	"testing"
)

// Mock MaxMind DB file needs to be created or mocked.
// Writing a real MMDB in test is hard without a library.
// For now, we will test the logic structure and handle initialization failure gracefully.

func TestInit_FileNotFound(t *testing.T) {
	err := Init("non_existent_file.mmdb")
	if err == nil {
		t.Error("expected error for non-existent file, got nil")
	}
}

func TestLookup_NotInitialized(t *testing.T) {
	Close() // Ensure closed
	_, err := LookupCountry(net.ParseIP("8.8.8.8"))
	if err == nil {
		t.Error("expected error when DB not initialized")
	}
}

func TestUpdateDB_InvalidURL(t *testing.T) {
	err := UpdateDB("http://invalid.url/test.mmdb", "test.mmdb")
	if err == nil {
		t.Error("expected error for invalid URL")
	}
}
