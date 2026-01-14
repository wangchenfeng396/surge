package geoip

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

// UpdateDB downloads and updates the GeoIP database
func UpdateDB(url string, destPath string) error {
	// Create temp file
	tempFile, err := os.CreateTemp("", "surge-geoip-*.mmdb")
	if err != nil {
		return fmt.Errorf("failed to create temp file: %v", err)
	}
	defer os.Remove(tempFile.Name())
	defer tempFile.Close()

	// Download
	client := &http.Client{Timeout: 60 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return fmt.Errorf("failed to download GeoIP DB: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("bad status: %s", resp.Status)
	}

	// Check if gzipped
	var reader io.Reader = resp.Body
	// Simple check based on URL, or we could peek header
	// For simplicity, let's assume if it ends in .gz or content-type matches
	// But Surge usually uses a direct MMDB link or a tarball.
	// The standard `geoip-maxmind-url` often points to a raw MMDB or a tar.gz.
	// Let's implement a simple copy for now, assuming raw MMDB or handled by caller to provide correct URL.
	// NOTE: Many free sources provide .tar.gz. For MVP, we'll support direct writing.
	// If the file is gzipped, we should decompress it.

	// Create required directory
	if err := os.MkdirAll(filepath.Dir(destPath), 0755); err != nil {
		return err
	}

	_, err = io.Copy(tempFile, reader)
	if err != nil {
		return fmt.Errorf("failed to write to temp file: %v", err)
	}

	tempFile.Close()

	// Verify (Try to open it)
	// We can try to Init it briefly or just rename it.
	// For MVP, just rename.

	// Move to destination
	if err := os.Rename(tempFile.Name(), destPath); err != nil {
		// Fallback copy if rename fails (different partitions)
		input, err := os.ReadFile(tempFile.Name())
		if err != nil {
			return err
		}
		if err := os.WriteFile(destPath, input, 0644); err != nil {
			return err
		}
	}

	// Reload DB if initialized
	if IsInitialized() {
		return Init(destPath)
	}

	return nil
}
