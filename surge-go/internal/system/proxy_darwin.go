package system

import (
	"fmt"
	"os/exec"
	"strings"
	"sync"
)

// ProxyManager manages system proxy settings
type ProxyManager struct {
	mu      sync.RWMutex
	enabled bool
	port    int
	service string
}

// NewProxyManager creates a new system proxy manager
func NewProxyManager() *ProxyManager {
	return &ProxyManager{
		enabled: false,
	}
}

// Enable enables system proxy
func (m *ProxyManager) Enable(port int) error {
	if port <= 0 || port > 65535 {
		return fmt.Errorf("invalid port: %d", port)
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	if m.enabled {
		return fmt.Errorf("system proxy already enabled")
	}

	// Detect active network service
	service, err := m.getActiveNetworkService()
	if err != nil {
		return fmt.Errorf("failed to detect network service: %w", err)
	}

	// Set HTTP proxy
	if err := m.runNetworkSetup(fmt.Sprintf("-setwebproxy '%s' 127.0.0.1 %d", service, port)); err != nil {
		return fmt.Errorf("failed to set HTTP proxy: %w", err)
	}

	// Set HTTPS proxy
	if err := m.runNetworkSetup(fmt.Sprintf("-setsecurewebproxy '%s' 127.0.0.1 %d", service, port)); err != nil {
		// Rollback HTTP proxy
		m.runNetworkSetup(fmt.Sprintf("-setwebproxystate '%s' off", service))
		return fmt.Errorf("failed to set HTTPS proxy: %w", err)
	}

	m.enabled = true
	m.port = port
	m.service = service

	return nil
}

// Disable disables system proxy
func (m *ProxyManager) Disable() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if !m.enabled {
		return nil
	}

	// Disable HTTP proxy
	if err := m.runNetworkSetup(fmt.Sprintf("-setwebproxystate '%s' off", m.service)); err != nil {
		return fmt.Errorf("failed to disable HTTP proxy: %w", err)
	}

	// Disable HTTPS proxy
	if err := m.runNetworkSetup(fmt.Sprintf("-setsecurewebproxystate '%s' off", m.service)); err != nil {
		return fmt.Errorf("failed to disable HTTPS proxy: %w", err)
	}

	m.enabled = false
	return nil
}

// IsEnabled returns whether system proxy is enabled
func (m *ProxyManager) IsEnabled() bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.enabled
}

// GetStatus returns the current proxy status
func (m *ProxyManager) GetStatus() (enabled bool, port int) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.enabled, m.port
}

// getActiveNetworkService detects the active network service
func (m *ProxyManager) getActiveNetworkService() (string, error) {
	output, err := exec.Command("networksetup", "-listallnetworkservices").Output()
	if err != nil {
		return "", err
	}

	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "*") || strings.HasPrefix(line, "An asterisk") {
			continue
		}

		// Prefer Wi-Fi or Ethernet
		if strings.Contains(line, "Wi-Fi") || strings.Contains(line, "Ethernet") {
			return line, nil
		}
	}

	// Return the first valid service if no Wi-Fi/Ethernet found
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line != "" && !strings.HasPrefix(line, "*") && !strings.HasPrefix(line, "An asterisk") {
			return line, nil
		}
	}

	return "", fmt.Errorf("no active network service found")
}

// runNetworkSetup runs networksetup command
func (m *ProxyManager) runNetworkSetup(args string) error {
	cmd := exec.Command("sh", "-c", "networksetup "+args)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("%w: %s", err, string(output))
	}
	return nil
}
