//go:build !darwin
// +build !darwin

package system

import "fmt"

// ProxyManager stub for non-Darwin platforms
type ProxyManager struct{}

func NewProxyManager() *ProxyManager {
	return &ProxyManager{}
}

func (m *ProxyManager) Enable(port int) error {
	return fmt.Errorf("system proxy not supported on this platform")
}

func (m *ProxyManager) Disable() error {
	return fmt.Errorf("system proxy not supported on this platform")
}

func (m *ProxyManager) IsEnabled() bool {
	return false
}

func (m *ProxyManager) GetStatus() (bool, int) {
	return false, 0
}
