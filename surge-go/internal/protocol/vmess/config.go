package vmess

import (
	"crypto/md5"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"

	"github.com/surge-proxy/surge-go/internal/protocol"
)

// Security encryption method
type Security string

const (
	SecurityAES128GCM        Security = "aes-128-gcm"
	SecurityChacha20Poly1305 Security = "chacha20-poly1305"
	SecurityAuto             Security = "auto"
	SecurityNone             Security = "none"
	SecurityAES128CFB        Security = "aes-128-cfb" // Legacy
)

// Config represents VMess proxy configuration
type Config struct {
	Name   string
	Server string
	Port   int

	// Authentication
	UUID    string // User ID
	AlterID int    // Legacy, usually 0 for AEAD

	// Encryption
	Security Security

	// Transport
	Network       string // tcp, ws, h2
	Path          string // WebSocket path or HTTP/2 path
	Host          string // WebSocket Host header or HTTP/2 authority
	Headers       map[string]string
	SNI           string // TLS Server Name Indication
	AllowInsecure bool   // Skip certificate verification

	// TLS
	TLS     bool
	TLSHost string // Deprecated, use SNI instead

	// TCP Fast Open
	TFO bool

	// AEAD (recommended, alterId should be 0)
	AEAD bool
}

// Validate validates the configuration
func (c *Config) Validate() error {
	if c.Server == "" {
		return errors.New("vmess: server cannot be empty")
	}
	if c.Port <= 0 || c.Port > 65535 {
		return errors.New("vmess: invalid port")
	}
	if c.UUID == "" {
		return errors.New("vmess: UUID cannot be empty")
	}
	if !isValidUUID(c.UUID) {
		return errors.New("vmess: invalid UUID format")
	}
	if c.AlterID < 0 || c.AlterID > 65535 {
		return errors.New("vmess: invalid alterID")
	}

	// Validate security
	switch c.Security {
	case SecurityAES128GCM, SecurityChacha20Poly1305, SecurityAuto, SecurityNone, SecurityAES128CFB:
		// Valid
	case "":
		c.Security = SecurityAuto
	default:
		return fmt.Errorf("vmess: unsupported security method: %s", c.Security)
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
		return fmt.Errorf("vmess: unsupported network type: %s", c.Network)
	}

	return nil
}

// FromProxyConfig creates VMess config from generic ProxyConfig
func FromProxyConfig(cfg *protocol.ProxyConfig) (*Config, error) {
	if cfg.Type != "vmess" {
		return nil, fmt.Errorf("invalid proxy type: %s, expected vmess", cfg.Type)
	}

	vmessCfg := &Config{
		Name:   cfg.Name,
		Server: cfg.Server,
		Port:   cfg.Port,
		AEAD:   true, // Default to AEAD
	}

	// Parse UUID (can be in 'uuid' or 'username' field)
	if uuid, ok := cfg.GetString("uuid"); ok {
		vmessCfg.UUID = uuid
	} else if uuid, ok := cfg.GetString("username"); ok {
		vmessCfg.UUID = uuid
	} else {
		return nil, errors.New("vmess: UUID not found in config")
	}

	// Parse AlterID
	if alterId, ok := cfg.GetInt("alterId"); ok {
		vmessCfg.AlterID = alterId
	} else if alterId, ok := cfg.GetInt("alter-id"); ok {
		vmessCfg.AlterID = alterId
	} else {
		vmessCfg.AlterID = 0 // Default to 0 (AEAD mode)
	}

	// Parse Security
	if security, ok := cfg.GetString("security"); ok {
		vmessCfg.Security = Security(security)
	} else {
		vmessCfg.Security = SecurityAuto
	}

	// Parse Network
	if network, ok := cfg.GetString("network"); ok {
		vmessCfg.Network = network
	} else {
		vmessCfg.Network = "tcp"
	}

	// Parse WebSocket options
	if ws, ok := cfg.GetBool("ws"); ok && ws {
		vmessCfg.Network = "ws"
	}
	if wsPath, ok := cfg.GetString("ws-path"); ok {
		vmessCfg.Path = wsPath
	}
	if wsHeaders, ok := cfg.GetString("ws-headers"); ok {
		vmessCfg.Headers = parseHeaders(wsHeaders)
	}

	// Parse TLS
	if tls, ok := cfg.GetBool("tls"); ok {
		vmessCfg.TLS = tls
	} else if tlsStr, ok := cfg.GetString("tls"); ok && tlsStr == "true" {
		vmessCfg.TLS = true
	}
	if sni, ok := cfg.GetString("sni"); ok {
		vmessCfg.SNI = sni
	}
	if tlsHost, ok := cfg.GetString("tls-host"); ok {
		if vmessCfg.SNI == "" {
			vmessCfg.SNI = tlsHost
		}
	}
	if skipCertVerify, ok := cfg.GetBool("skip-cert-verify"); ok {
		vmessCfg.AllowInsecure = skipCertVerify
	}

	// Parse TCP Fast Open
	if tfo, ok := cfg.GetBool("tfo"); ok {
		vmessCfg.TFO = tfo
	}

	// Parse AEAD
	if vmessAead, ok := cfg.GetBool("vmess-aead"); ok {
		vmessCfg.AEAD = vmessAead
	}
	if vmessAead, ok := cfg.GetBool("aead"); ok {
		vmessCfg.AEAD = vmessAead
	}

	// If alterID > 0, AEAD should be false (legacy mode) unless explicitly enabled
	isAeadSet, _ := cfg.GetBool("vmess-aead")
	if !isAeadSet {
		isAeadSet, _ = cfg.GetBool("aead")
	}

	if vmessCfg.AlterID > 0 && !isAeadSet {
		vmessCfg.AEAD = false
	}

	return vmessCfg, vmessCfg.Validate()
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

// GenerateCmdKey generates command key from UUID
func GenerateCmdKey(uuid string) []byte {
	// Remove hyphens from UUID
	uuid = strings.ReplaceAll(uuid, "-", "")

	// Convert to bytes
	md5hash := md5.Sum([]byte(uuid + "c48619fe-8f02-49e0-b9e9-edf763e17e21"))
	return md5hash[:]
}

// ToHex converts UUID to hex string without hyphens
func ToHex(uuid string) string {
	return strings.ToLower(strings.ReplaceAll(uuid, "-", ""))
}

// UUIDToBytes converts UUID string to 16 bytes
func UUIDToBytes(uuid string) ([]byte, error) {
	hexStr := ToHex(uuid)
	if len(hexStr) != 32 {
		return nil, errors.New("invalid UUID length")
	}
	bytes, err := hex.DecodeString(hexStr)
	if err != nil {
		return nil, err
	}
	return bytes, nil
}
