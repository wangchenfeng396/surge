package policy

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/surge-proxy/surge-go/internal/config"
	"github.com/surge-proxy/surge-go/internal/protocol"
	"github.com/surge-proxy/surge-go/internal/protocol/trojan"
	"github.com/surge-proxy/surge-go/internal/protocol/vless"
	"github.com/surge-proxy/surge-go/internal/protocol/vmess"
)

// Subscription manages dynamic proxy updates
type Subscription struct {
	URL            string
	UpdateInterval time.Duration
	Group          UpdatableGroup

	mu sync.Mutex
}

// NewSubscription creates a subscription manager
func NewSubscription(url string, interval int, group UpdatableGroup) *Subscription {
	return &Subscription{
		URL:            url,
		UpdateInterval: time.Duration(interval) * time.Second,
		Group:          group,
	}
}

// StartAutoUpdate starts background update loop
func (s *Subscription) StartAutoUpdate() {
	if s.UpdateInterval <= 0 {
		return
	}
	// Initial update
	go func() {
		_ = s.Update()
	}()

	go func() {
		ticker := time.NewTicker(s.UpdateInterval)
		defer ticker.Stop()
		for range ticker.C {
			_ = s.Update()
		}
	}()
}

// Update fetches and parses proxies
func (s *Subscription) Update() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	log.Printf("Subscription: fetching %s", s.URL)

	client := &http.Client{
		Timeout: 30 * time.Second,
	}

	// 1. Fetch
	resp, err := client.Get(s.URL)
	if err != nil {
		log.Printf("Subscription: fetch failed: %v", err)
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		log.Printf("Subscription: status code %d", resp.StatusCode)
		return fmt.Errorf("subscription fetch failed: %d", resp.StatusCode)
	}

	content, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("Subscription: read failed: %v", err)
		return err
	}
	log.Printf("Subscription: fetched %d bytes", len(content))

	// 2. Decode/Parse
	lines := strings.Split(string(content), "\n")

	// Detect Base64
	// Try multiple encodings
	strContent := strings.TrimSpace(string(content))
	var decoded []byte

	encodings := []*base64.Encoding{
		base64.StdEncoding,
		base64.URLEncoding,
		base64.RawStdEncoding,
		base64.RawURLEncoding,
	}

	for _, enc := range encodings {
		decoded, err = enc.DecodeString(strContent)
		if err == nil {
			lines = strings.Split(string(decoded), "\n")
			break
		}
	}

	if err != nil {
		// Treating as plain text is default if lines weren't updated
	}

	newProxies := make(map[string]protocol.Dialer)
	newNames := make([]string, 0)

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") || strings.HasPrefix(line, "//") {
			continue
		}

		// Handle vmess:// URI
		if strings.HasPrefix(line, "vmess://") {
			// Parse vmess URI
			b64 := line[8:]
			// Handle URL-safe or Std encoding
			decoded, err := base64.StdEncoding.DecodeString(b64)
			if err != nil {
				decoded, err = base64.URLEncoding.DecodeString(b64)
			}
			if err != nil {
				log.Printf("Subscription: failed to decode vmess URI: %v", err)
				continue
			}

			// Unmarshal JSON
			var v struct {
				V    string      `json:"v"`
				PS   string      `json:"ps"`
				Add  string      `json:"add"`
				Port interface{} `json:"port"` // int or string
				ID   string      `json:"id"`
				AID  interface{} `json:"aid"` // int or string
				Scy  string      `json:"scy"`
				Net  string      `json:"net"`
				Type string      `json:"type"`
				Host string      `json:"host"`
				Path string      `json:"path"`
				TLS  string      `json:"tls"`
				SNI  string      `json:"sni"`
			}
			if err := json.Unmarshal(decoded, &v); err != nil {
				log.Printf("Subscription: failed to unmarshal vmess JSON: %v", err)
				continue
			}

			// Map to protocol.ProxyConfig
			name := v.PS
			if name == "" {
				name = fmt.Sprintf("VMess-%s-%v", v.Add, v.Port)
			}

			opts := make(map[string]interface{})
			opts["uuid"] = v.ID
			opts["alterId"] = fmt.Sprintf("%v", v.AID)
			opts["security"] = v.Scy
			opts["network"] = v.Net
			opts["type"] = v.Type
			opts["host"] = v.Host
			opts["path"] = v.Path
			if v.TLS == "tls" {
				opts["tls"] = true
			}
			if v.SNI != "" {
				opts["sni"] = v.SNI
			}

			portVal := 0
			switch p := v.Port.(type) {
			case float64:
				portVal = int(p)
			case string:
				portVal, _ = strconv.Atoi(p)
			}

			pConfig := &protocol.ProxyConfig{
				Name:    name,
				Type:    "vmess",
				Server:  v.Add,
				Port:    portVal,
				Options: opts,
			}

			dialer, err := vmess.NewClientFromProxyConfig(pConfig)
			if err != nil {
				log.Printf("Subscription: failed to create vmess client: %v", err)
				continue
			}

			newProxies[name] = dialer
			newNames = append(newNames, name)
			continue
		}

		// Handle vmess:// URI
		if strings.HasPrefix(line, "vmess://") {
			// Parse vmess URI
			b64 := line[8:]
			// Handle URL-safe or Std encoding
			decoded, err := base64.StdEncoding.DecodeString(b64)
			if err != nil {
				decoded, err = base64.URLEncoding.DecodeString(b64)
			}
			if err != nil {
				log.Printf("Subscription: failed to decode vmess URI: %v", err)
				continue
			}

			// Unmarshal JSON
			var v struct {
				V    string      `json:"v"`
				PS   string      `json:"ps"`
				Add  string      `json:"add"`
				Port interface{} `json:"port"` // int or string
				ID   string      `json:"id"`
				AID  interface{} `json:"aid"` // int or string
				Scy  string      `json:"scy"`
				Net  string      `json:"net"`
				Type string      `json:"type"`
				Host string      `json:"host"`
				Path string      `json:"path"`
				TLS  string      `json:"tls"`
				SNI  string      `json:"sni"`
			}
			if err := json.Unmarshal(decoded, &v); err != nil {
				log.Printf("Subscription: failed to unmarshal vmess JSON: %v", err)
				continue
			}

			// Map to protocol.ProxyConfig
			name := v.PS
			if name == "" {
				name = fmt.Sprintf("VMess-%s-%v", v.Add, v.Port)
			}
			// Avoid duplicate names? Engine or Group handles overwrites but we use map here.
			// If duplicate name in list, last one wins.

			opts := make(map[string]interface{})
			opts["uuid"] = v.ID
			opts["alterId"] = fmt.Sprintf("%v", v.AID)
			opts["security"] = v.Scy
			opts["network"] = v.Net
			opts["type"] = v.Type
			opts["host"] = v.Host
			opts["path"] = v.Path
			if v.TLS == "tls" {
				opts["tls"] = true
			}
			if v.SNI != "" {
				opts["sni"] = v.SNI
			}

			portVal := 0
			switch p := v.Port.(type) {
			case float64:
				portVal = int(p)
			case string:
				portVal, _ = strconv.Atoi(p)
			}

			pConfig := &protocol.ProxyConfig{
				Name:    name,
				Type:    "vmess",
				Server:  v.Add,
				Port:    portVal,
				Options: opts,
			}

			dialer, err := vmess.NewClientFromProxyConfig(pConfig)
			if err != nil {
				log.Printf("Subscription: failed to create vmess client: %v", err)
				continue
			}

			newProxies[name] = dialer
			newNames = append(newNames, name)
			continue
		}

		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			log.Printf("Subscription: skipping line (no '='): %s", line[:min(len(line), 50)])
			continue
		}

		name := strings.TrimSpace(parts[0])
		cfgStr := strings.TrimSpace(parts[1])

		proxyCfg := config.ParseSingleProxy(name, cfgStr)
		if proxyCfg == nil {
			continue
		}

		var dialer protocol.Dialer
		var cerr error

		switch strings.ToLower(proxyCfg.Type) {
		case "vmess":
			dialer, cerr = vmess.NewClientFromProxyConfig(toProtocolConfig(proxyCfg))
		case "trojan":
			dialer, cerr = trojan.NewClientFromProxyConfig(toProtocolConfig(proxyCfg))
		case "vless":
			dialer, cerr = vless.NewClientFromProxyConfig(toProtocolConfig(proxyCfg))
		default:
			// log.Printf("DEBUG: Unknown type %s", proxyCfg.Type)
		}

		if cerr == nil && dialer != nil {
			newProxies[name] = dialer
			newNames = append(newNames, name)
		} else {
			// log.Printf("Failed to create proxy %s: %v", name, cerr)
		}
	}

	log.Printf("Subscription: parsed %d proxies", len(newNames))

	// 3. Update Group
	if s.Group != nil {
		s.Group.UpdateProxies(newNames, newProxies)
		log.Printf("Subscription: updated group with %d proxies", len(newNames))
	} else {
		log.Println("Subscription: group is nil!")
	}

	return nil
}

// toProtocolConfig converts internal/config.ProxyConfig to protocol.ProxyConfig
func toProtocolConfig(c *config.ProxyConfig) *protocol.ProxyConfig {
	opts := make(map[string]interface{})
	for k, v := range c.Parameters {
		opts[k] = v
	}
	// Also add specific typed fields to opts if needed, or rely on them being in Parameters if parser put them there?
	// ParseSingleProxy puts everything in Parameters, AND sets fields.
	// protocol.ProxyConfig uses Options map.
	// Let's populate Options map from fields + parameters.

	if c.Username != "" {
		opts["username"] = c.Username
	}
	if c.Password != "" {
		opts["password"] = c.Password
	}
	if c.SNI != "" {
		opts["sni"] = c.SNI
	}
	if c.SkipCertVerify {
		opts["skip-cert-verify"] = true
	}
	if c.TLS {
		opts["tls"] = true
	}

	return &protocol.ProxyConfig{
		Name:    c.Name,
		Type:    c.Type,
		Server:  c.Server,
		Port:    c.Port,
		Options: opts,
	}
}
