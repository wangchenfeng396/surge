package mitm

import (
	"crypto/tls"
	"fmt"
	"strings"

	"github.com/surge-proxy/surge-go/internal/config"
)

// Manager handles MITM logic and config
type Manager struct {
	cfg         *config.MITMConfig
	CertManager *CertManager
}

// NewManager creates a new MITM manager
func NewManager(cfg *config.MITMConfig) (*Manager, error) {
	mgr := &Manager{
		cfg:         cfg,
		CertManager: NewCertManager(),
	}

	if cfg.Enabled && cfg.CAP12 != "" {
		// Try to load CA
		// Usually password is provided or empty
		err := mgr.CertManager.LoadCAFromP12(cfg.CAP12, cfg.CAPassphrase)
		if err != nil {
			// Log error but stick with non-working MITM or return error?
			// Return error to warn user
			return nil, err
		}
	}

	return mgr, nil
}

// ShouldIntercept checks if the hostname matches MITM rules
func (m *Manager) ShouldIntercept(host string) bool {
	if !m.cfg.Enabled {
		return false
	}

	// Strip port
	if strings.Contains(host, ":") {
		host = strings.Split(host, ":")[0]
	}

	// Check Disabled list first (Exclusion)
	for _, pattern := range m.cfg.HostnameDisabled {
		if match(host, pattern) {
			return false
		}
	}

	// Check Allowed list (Inclusion)
	for _, pattern := range m.cfg.Hostname {
		if match(host, pattern) {
			return true
		}
	}

	return false
}

// match checks wildcard patterns like *.google.com
func match(host, pattern string) bool {
	// Simple wildcard support
	// surge: *google.com matches www.google.com
	// surge: *.google.com matches www.google.com
	// surge: google.com matches google.com

	host = strings.ToLower(host)
	pattern = strings.ToLower(pattern)

	if pattern == "*" {
		return true
	}

	if strings.HasPrefix(pattern, "*") {
		suffix := pattern[1:] // .google.com or google.com
		return strings.HasSuffix(host, suffix)
	}

	return host == pattern
}

// GetCertificate implements tls.Config.GetCertificate
func (m *Manager) GetCertificate(hello *tls.ClientHelloInfo) (*tls.Certificate, error) {
	if m.CertManager == nil {
		return nil, fmt.Errorf("CertManager not initialized")
	}
	return m.CertManager.GetCertificate(hello)
}
