package config

import (
	"bufio"
	"encoding/base64"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"
)

// SubscriptionManager handles downloading and parsing of proxy subscriptions
type SubscriptionManager struct {
	cache  map[string][]string
	mu     sync.RWMutex
	client *http.Client
}

var (
	globalSubManager *SubscriptionManager
	onceSub          sync.Once
)

// GetSubscriptionManager returns the singleton instance
func GetSubscriptionManager() *SubscriptionManager {
	onceSub.Do(func() {
		globalSubManager = &SubscriptionManager{
			cache: make(map[string][]string),
			client: &http.Client{
				Timeout: 30 * time.Second,
			},
		}
	})
	return globalSubManager
}

// GetProxies retrieves proxies from subscription URL
func (sm *SubscriptionManager) GetProxies(url string) ([]string, error) {
	sm.mu.RLock()
	if proxies, ok := sm.cache[url]; ok {
		sm.mu.RUnlock()
		return proxies, nil
	}
	sm.mu.RUnlock()

	// Download
	resp, err := sm.client.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("failed to download subscription, status: %d", resp.StatusCode)
	}

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	content := string(bodyBytes)

	// Check if Base64
	if isBase64(content) {
		decoded, err := base64.StdEncoding.DecodeString(content)
		if err == nil {
			content = string(decoded)
		}
	}

	var proxies []string
	scanner := bufio.NewScanner(strings.NewReader(content))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line != "" && !strings.HasPrefix(line, "#") && !strings.HasPrefix(line, "//") {
			proxies = append(proxies, line)
		}
	}

	sm.mu.Lock()
	sm.cache[url] = proxies
	sm.mu.Unlock()

	return proxies, nil
}

func isBase64(s string) bool {
	s = strings.TrimSpace(s)
	if len(s)%4 != 0 {
		return false
	}
	// Simple check - incomplete but works for most full b64 bodies
	_, err := base64.StdEncoding.DecodeString(s)
	return err == nil
}
