package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestConfigManager_LoadConfig(t *testing.T) {
	// Create temp config file
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "test.conf")

	testConfig := `[General]
loglevel = notify
dns-server = 223.5.5.5, 114.114.114.114
ipv6 = false

[Proxy]
TestProxy = vmess, test.com, 443, username=test-uuid

[Proxy Group]
Auto = url-test, TestProxy, url=http://www.gstatic.com/generate_204

[Rule]
DOMAIN,google.com,Auto
FINAL,DIRECT
`

	err := os.WriteFile(configPath, []byte(testConfig), 0644)
	if err != nil {
		t.Fatalf("Failed to create test config: %v", err)
	}

	// Test loading
	manager, err := NewConfigManager(configPath)
	if err != nil {
		t.Fatalf("Failed to create config manager: %v", err)
	}

	// Verify General config
	general := manager.GetGeneral()
	if general.LogLevel != "notify" {
		t.Errorf("Expected loglevel 'notify', got '%s'", general.LogLevel)
	}

	if len(general.DNSServer) != 2 {
		t.Errorf("Expected 2 DNS servers, got %d", len(general.DNSServer))
	}

	// Verify Proxies
	proxies := manager.GetProxies()
	if len(proxies) != 1 {
		t.Fatalf("Expected 1 proxy, got %d", len(proxies))
	}

	if proxies[0].Name != "TestProxy" {
		t.Errorf("Expected proxy name 'TestProxy', got '%s'", proxies[0].Name)
	}

	// Verify Proxy Groups
	groups := manager.GetProxyGroups()
	if len(groups) != 1 {
		t.Fatalf("Expected 1 proxy group, got %d", len(groups))
	}

	if groups[0].Name != "Auto" {
		t.Errorf("Expected group name 'Auto', got '%s'", groups[0].Name)
	}

	// Verify Rules
	rules := manager.GetRules()
	if len(rules) != 2 {
		t.Fatalf("Expected 2 rules, got %d", len(rules))
	}

	if rules[0].Type != "DOMAIN" {
		t.Errorf("Expected rule type 'DOMAIN', got '%s'", rules[0].Type)
	}
}

func TestConfigManager_UpdateGeneral(t *testing.T) {
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "test.conf")

	// Create minimal config
	err := os.WriteFile(configPath, []byte("[General]\nloglevel = notify\n"), 0644)
	if err != nil {
		t.Fatalf("Failed to create test config: %v", err)
	}

	manager, err := NewConfigManager(configPath)
	if err != nil {
		t.Fatalf("Failed to create config manager: %v", err)
	}

	// Update config
	newGeneral := &GeneralConfig{
		LogLevel:  "info",
		DNSServer: []string{"8.8.8.8", "1.1.1.1"},
		IPv6:      true,
	}

	err = manager.UpdateGeneral(newGeneral)
	if err != nil {
		t.Fatalf("Failed to update general config: %v", err)
	}

	// Verify update
	general := manager.GetGeneral()
	if general.LogLevel != "info" {
		t.Errorf("Expected loglevel 'info', got '%s'", general.LogLevel)
	}

	if !general.IPv6 {
		t.Error("Expected IPv6 to be true")
	}
}

func TestConfigManager_ProxyOperations(t *testing.T) {
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "test.conf")

	err := os.WriteFile(configPath, []byte("[General]\nloglevel = notify\n\n[Proxy]\n"), 0644)
	if err != nil {
		t.Fatalf("Failed to create test config: %v", err)
	}

	manager, err := NewConfigManager(configPath)
	if err != nil {
		t.Fatalf("Failed to create config manager: %v", err)
	}

	// Test Add
	proxy := &ProxyConfig{
		Name:   "TestVMess",
		Type:   "vmess",
		Server: "example.com",
		Port:   443,
	}

	err = manager.AddProxy(proxy)
	if err != nil {
		t.Fatalf("Failed to add proxy: %v", err)
	}

	proxies := manager.GetProxies()
	if len(proxies) != 1 {
		t.Fatalf("Expected 1 proxy after add, got %d", len(proxies))
	}

	// Test Update
	proxy.Port = 8443
	err = manager.UpdateProxy("TestVMess", proxy)
	if err != nil {
		t.Fatalf("Failed to update proxy: %v", err)
	}

	proxies = manager.GetProxies()
	if proxies[0].Port != 8443 {
		t.Errorf("Expected port 8443, got %d", proxies[0].Port)
	}

	// Test Delete
	err = manager.DeleteProxy("TestVMess")
	if err != nil {
		t.Fatalf("Failed to delete proxy: %v", err)
	}

	proxies = manager.GetProxies()
	if len(proxies) != 0 {
		t.Errorf("Expected 0 proxies after delete, got %d", len(proxies))
	}
}

func TestConfigManager_RuleOperations(t *testing.T) {
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "test.conf")

	err := os.WriteFile(configPath, []byte("[General]\nloglevel = notify\n\n[Rule]\n"), 0644)
	if err != nil {
		t.Fatalf("Failed to create test config: %v", err)
	}

	manager, err := NewConfigManager(configPath)
	if err != nil {
		t.Fatalf("Failed to create config manager: %v", err)
	}

	// Test Add
	rule := &RuleConfig{
		Type:   "DOMAIN",
		Value:  "google.com",
		Policy: "PROXY",
	}

	err = manager.AddRule(rule)
	if err != nil {
		t.Fatalf("Failed to add rule: %v", err)
	}

	rules := manager.GetRules()
	if len(rules) != 1 {
		t.Fatalf("Expected 1 rule, got %d", len(rules))
	}

	// Test Update
	rule.Policy = "DIRECT"
	err = manager.UpdateRule(0, rule)
	if err != nil {
		t.Fatalf("Failed to update rule: %v", err)
	}

	rules = manager.GetRules()
	if rules[0].Policy != "DIRECT" {
		t.Errorf("Expected policy 'DIRECT', got '%s'", rules[0].Policy)
	}

	// Test Delete
	err = manager.DeleteRule(0)
	if err != nil {
		t.Fatalf("Failed to delete rule: %v", err)
	}

	rules = manager.GetRules()
	if len(rules) != 0 {
		t.Errorf("Expected 0 rules after delete, got %d", len(rules))
	}
}

func TestConfigManager_Save(t *testing.T) {
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "test.conf")

	initialConfig := `[General]
loglevel = notify

[Proxy]
Test = vmess, test.com, 443

[Rule]
FINAL,DIRECT
`

	err := os.WriteFile(configPath, []byte(initialConfig), 0644)
	if err != nil {
		t.Fatalf("Failed to create test config: %v", err)
	}

	manager, err := NewConfigManager(configPath)
	if err != nil {
		t.Fatalf("Failed to create config manager: %v", err)
	}

	// Make changes
	general := manager.GetGeneral()
	general.LogLevel = "info"
	manager.UpdateGeneral(general)

	// Save
	err = manager.Save()
	if err != nil {
		t.Fatalf("Failed to save config: %v", err)
	}

	// Reload and verify
	manager2, err := NewConfigManager(configPath)
	if err != nil {
		t.Fatalf("Failed to reload config: %v", err)
	}

	if manager2.GetGeneral().LogLevel != "info" {
		t.Error("Config was not persisted correctly")
	}
}

func TestConfigManager_ConcurrentAccess(t *testing.T) {
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "test.conf")

	err := os.WriteFile(configPath, []byte("[General]\nloglevel = notify\n"), 0644)
	if err != nil {
		t.Fatalf("Failed to create test config: %v", err)
	}

	manager, err := NewConfigManager(configPath)
	if err != nil {
		t.Fatalf("Failed to create config manager: %v", err)
	}

	// Concurrent reads
	done := make(chan bool)
	for i := 0; i < 10; i++ {
		go func() {
			_ = manager.GetGeneral()
			_ = manager.GetProxies()
			_ = manager.GetRules()
			done <- true
		}()
	}

	for i := 0; i < 10; i++ {
		<-done
	}

	// No crash = success
}
