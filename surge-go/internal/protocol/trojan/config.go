package trojan

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"

	"github.com/surge-proxy/surge-go/internal/protocol"
)

// Config represents Trojan proxy configuration
type Config struct {
	Name     string
	Server   string
	Port     int
	Password string

	// TLS (Trojan always uses TLS)
	SNI           string // TLS Server Name Indication
	AllowInsecure bool   // Skip certificate verification

	// TCP Fast Open
	TFO bool

	// WebSocket (optional, some Trojan implementations support it)
	WebSocket bool
	WSPath    string
	WSHost    string
}

// Validate validates the configuration
func (c *Config) Validate() error {
	if c.Server == "" {
		return errors.New("trojan: server cannot be empty")
	}
	if c.Port <= 0 || c.Port > 65535 {
		return errors.New("trojan: invalid port")
	}
	if c.Password == "" {
		return errors.New("trojan: password cannot be empty")
	}
	return nil
}

// FromProxyConfig creates Trojan config from generic ProxyConfig
func FromProxyConfig(cfg *protocol.ProxyConfig) (*Config, error) {
	if cfg.Type != "trojan" {
		return nil, fmt.Errorf("invalid proxy type: %s, expected trojan", cfg.Type)
	}

	trojanCfg := &Config{
		Name:   cfg.Name,
		Server: cfg.Server,
		Port:   cfg.Port,
	}

	// Parse Password (can be in 'password' or 'username' field)
	if password, ok := cfg.GetString("password"); ok {
		trojanCfg.Password = password
	} else if username, ok := cfg.GetString("username"); ok {
		trojanCfg.Password = username
	} else {
		return nil, errors.New("trojan: password not found in config")
	}

	// Parse SNI
	if sni, ok := cfg.GetString("sni"); ok {
		trojanCfg.SNI = sni
	}

	// Parse skip-cert-verify
	if skipCertVerify, ok := cfg.GetBool("skip-cert-verify"); ok {
		trojanCfg.AllowInsecure = skipCertVerify
	}

	// Parse TCP Fast Open
	if tfo, ok := cfg.GetBool("tfo"); ok {
		trojanCfg.TFO = tfo
	}

	// Parse WebSocket options (some implementations support this)
	if ws, ok := cfg.GetBool("ws"); ok {
		trojanCfg.WebSocket = ws
	}
	if wsPath, ok := cfg.GetString("ws-path"); ok {
		trojanCfg.WSPath = wsPath
		trojanCfg.WebSocket = true
	}
	if wsHost, ok := cfg.GetString("ws-host"); ok {
		trojanCfg.WSHost = wsHost
	}

	return trojanCfg, trojanCfg.Validate()
}

// GeneratePasswordHash generates SHA224 hash of password for Trojan authentication
func GeneratePasswordHash(password string) string {
	hash := sha256.Sum224([]byte(password))
	return hex.EncodeToString(hash[:])
}

// GetSNI returns the SNI to use for TLS
func (c *Config) GetSNI() string {
	if c.SNI != "" {
		return c.SNI
	}
	return c.Server
}
