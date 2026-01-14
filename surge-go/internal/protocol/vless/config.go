package vless

import (
	"encoding/hex"
	"errors"
	"fmt"
	"strings"

	"github.com/surge-proxy/surge-go/internal/protocol"
)

// Config represents VLESS proxy configuration
type Config struct {
	Name   string
	Server string
	Port   int
	UUID   string // User ID

	// Encryption (VLESS usually uses "none")
	Encryption string

	// Transport
	Network string // tcp, ws, h2
	Path    string // WebSocket path or HTTP/2 path
	Host    string // WebSocket Host header
	Headers map[string]string

	// TLS
	TLS           bool
	SNI           string // TLS Server Name Indication
	AllowInsecure bool   // Skip certificate verification

	// TCP Fast Open
	TFO bool

	// Flow control (xtls-rprx-vision, etc.)
	Flow string
}

// Validate validates the configuration
func (c *Config) Validate() error {
	if c.Server == "" {
		return errors.New("vless: server cannot be empty")
	}
	if c.Port <= 0 || c.Port > 65535 {
		return errors.New("vless: invalid port")
	}
	if c.UUID == "" {
		return errors.New("vless: UUID cannot be empty")
	}
	if !isValidUUID(c.UUID) {
		return errors.New("vless: invalid UUID format")
	}

	// Validate encryption
	if c.Encryption == "" {
		c.Encryption = "none"
	}
	if c.Encryption != "none" {
		return fmt.Errorf("vless: unsupported encryption: %s (only 'none' is supported)", c.Encryption)
	}

	// Validate network
	switch c.Network {
	case "tcp", "ws", "websocket", "h2", "http", "":
		if c.Network == "" {
			c.Network = "tcp"
		}
		if c.Network == "websocket" {
			c.Network = "ws"
		}
		if c.Network == "http" {
			c.Network = "h2"
		}
	default:
		return fmt.Errorf("vless: unsupported network type: %s", c.Network)
	}

	return nil
}

// FromProxyConfig creates VLESS config from generic ProxyConfig
func FromProxyConfig(cfg *protocol.ProxyConfig) (*Config, error) {
	if cfg.Type != "vless" {
		return nil, fmt.Errorf("invalid proxy type: %s, expected vless", cfg.Type)
	}

	vlessCfg := &Config{
		Name:       cfg.Name,
		Server:     cfg.Server,
		Port:       cfg.Port,
		Encryption: "none", // Default
	}

	// Parse UUID (can be in 'uuid' or 'username' field)
	if uuid, ok := cfg.GetString("uuid"); ok {
		vlessCfg.UUID = uuid
	} else if uuid, ok := cfg.GetString("username"); ok {
		vlessCfg.UUID = uuid
	} else {
		return nil, errors.New("vless: UUID not found in config")
	}

	// Parse Encryption
	if encryption, ok := cfg.GetString("encryption"); ok {
		vlessCfg.Encryption = encryption
	}

	// Parse Network
	if network, ok := cfg.GetString("network"); ok {
		vlessCfg.Network = network
	} else {
		vlessCfg.Network = "tcp"
	}

	// Parse WebSocket options
	if ws, ok := cfg.GetBool("ws"); ok && ws {
		vlessCfg.Network = "ws"
	}
	if wsPath, ok := cfg.GetString("ws-path"); ok {
		vlessCfg.Path = wsPath
	}
	if wsHost, ok := cfg.GetString("ws-host"); ok {
		vlessCfg.Host = wsHost
	}
	if wsHeaders, ok := cfg.GetString("ws-headers"); ok {
		vlessCfg.Headers = parseHeaders(wsHeaders)
	}

	// Parse TLS
	if tls, ok := cfg.GetBool("tls"); ok {
		vlessCfg.TLS = tls
	}
	if sni, ok := cfg.GetString("sni"); ok {
		vlessCfg.SNI = sni
	}
	if skipCertVerify, ok := cfg.GetBool("skip-cert-verify"); ok {
		vlessCfg.AllowInsecure = skipCertVerify
	}

	// Parse TCP Fast Open
	if tfo, ok := cfg.GetBool("tfo"); ok {
		vlessCfg.TFO = tfo
	}

	// Parse Flow
	if flow, ok := cfg.GetString("flow"); ok {
		vlessCfg.Flow = flow
	}

	return vlessCfg, vlessCfg.Validate()
}

// isValidUUID checks if the string is a valid UUID format
func isValidUUID(uuid string) bool {
	uuid = strings.ToLower(uuid)
	uuid = strings.ReplaceAll(uuid, "-", "")
	if len(uuid) != 32 {
		return false
	}
	for _, c := range uuid {
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) {
			return false
		}
	}
	return true
}

// parseHeaders parses header string to map
func parseHeaders(s string) map[string]string {
	headers := make(map[string]string)
	parts := strings.Split(s, "|")
	for _, part := range parts {
		kv := strings.SplitN(part, ":", 2)
		if len(kv) == 2 {
			headers[strings.TrimSpace(kv[0])] = strings.TrimSpace(kv[1])
		}
	}
	return headers
}

// UUIDToBytes converts UUID string to 16 bytes
func UUIDToBytes(uuid string) ([]byte, error) {
	hexStr := strings.ToLower(strings.ReplaceAll(uuid, "-", ""))
	if len(hexStr) != 32 {
		return nil, errors.New("invalid UUID length")
	}
	bytes, err := hex.DecodeString(hexStr)
	if err != nil {
		return nil, err
	}
	return bytes, nil
}

// GetSNI returns the SNI to use for TLS
func (c *Config) GetSNI() string {
	if c.SNI != "" {
		return c.SNI
	}
	if c.Host != "" {
		return c.Host
	}
	return c.Server
}
