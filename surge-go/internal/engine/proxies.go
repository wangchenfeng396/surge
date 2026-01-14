package engine

import (
	"fmt"
	"strings"

	"github.com/surge-proxy/surge-go/internal/config"
	"github.com/surge-proxy/surge-go/internal/protocol"
	"github.com/surge-proxy/surge-go/internal/protocol/trojan"
	"github.com/surge-proxy/surge-go/internal/protocol/vless"
	"github.com/surge-proxy/surge-go/internal/protocol/vmess"
)

// loadProxies loads proxies from configuration
func (e *Engine) loadProxies(cfg *config.SurgeConfig) error {
	e.Proxies = make(map[string]protocol.Dialer)

	for _, pConfig := range cfg.Proxies {
		dialer, err := createProxy(pConfig)
		if err != nil {
			return fmt.Errorf("failed to create proxy %s: %v", pConfig.Name, err)
		}
		e.Proxies[pConfig.Name] = dialer
	}

	return nil
}

// createProxy creates a Dialer from ProxyConfig
func createProxy(cfg *config.ProxyConfig) (protocol.Dialer, error) {
	// Convert config.ProxyConfig to protocol.ProxyConfig
	// We map the flat config fields to the Options map expected by protocols
	pConfig := &protocol.ProxyConfig{
		Name:    cfg.Name,
		Type:    strings.ToLower(cfg.Type),
		Server:  cfg.Server,
		Port:    cfg.Port,
		Options: make(map[string]interface{}),
	}

	// Populate common options
	pConfig.Options["username"] = cfg.Username
	pConfig.Options["password"] = cfg.Password
	pConfig.Options["auth"] = cfg.Auth
	pConfig.Options["tls"] = cfg.TLS
	pConfig.Options["sni"] = cfg.SNI
	pConfig.Options["skip_cert_verify"] = cfg.SkipCertVerify
	pConfig.Options["tfo"] = cfg.TFO
	pConfig.Options["udp"] = cfg.UDP

	// Add format specific parameters (like vmess uuid, trojan password etc are often implicitly handled via username/password or specialized fields)
	// But Surge config mapping needs to be accurate.
	// VMess: username -> uuid, ws-path -> parameters
	// Trojan: password -> password
	// VLESS: username -> uuid

	// Copy Parameters map
	for k, v := range cfg.Parameters {
		pConfig.Options[k] = v
	}

	// Protocol specific adjustments if needed
	switch pConfig.Type {
	case "vmess":
		// VMess uses 'username' field for UUID in Surge config typically
		if uuid, ok := cfg.Parameters["uuid"]; ok {
			pConfig.Options["uuid"] = uuid
		} else if cfg.Username != "" {
			pConfig.Options["uuid"] = cfg.Username
		}

		// Map WS options if present in parameters
		// 'ws' -> net, 'ws-path' -> path, 'ws-headers' -> headers
		if val, ok := cfg.Parameters["ws"]; ok && val == "true" {
			pConfig.Options["network"] = "ws"
		}
		if val, ok := cfg.Parameters["ws-path"]; ok {
			pConfig.Options["path"] = val
		}
		// Headers handling might need parsing if it's a map

	case "trojan":
		// Trojan uses 'password'

	case "vless":
		if uuid, ok := cfg.Parameters["uuid"]; ok {
			pConfig.Options["uuid"] = uuid
		} else if cfg.Username != "" {
			pConfig.Options["uuid"] = cfg.Username
		}
	}

	// Delegate to specific protocol constructors
	switch pConfig.Type {
	case "vmess":
		return vmess.NewClientFromProxyConfig(pConfig)
	case "trojan":
		return trojan.NewClientFromProxyConfig(pConfig)
	case "vless":
		return vless.NewClientFromProxyConfig(pConfig)
	case "ss", "shadowsocks":
		// Not implemented yet?
		return nil, fmt.Errorf("shadowsocks not implemented")
	default:
		return nil, fmt.Errorf("unsupported proxy type: %s", pConfig.Type)
	}
}
