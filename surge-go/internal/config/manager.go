package config

import (
	"fmt"
	"os"
	"strings"
	"sync"
)

// ConfigManager manages the Surge configuration with thread-safe operations
type ConfigManager struct {
	configPath string
	config     *SurgeConfig
	mu         sync.RWMutex
}

// NewConfigManager creates a new configuration manager
func NewConfigManager(configPath string) (*ConfigManager, error) {
	manager := &ConfigManager{
		configPath: configPath,
		config:     NewSurgeConfig(),
	}

	// Try to load existing config
	if err := manager.Load(); err != nil {
		// If file doesn't exist, that's ok - we'll use default config
		if !os.IsNotExist(err) {
			return nil, err
		}
	}

	return manager, nil
}

// Load reads and parses the configuration file
func (m *ConfigManager) Load() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	data, err := os.ReadFile(m.configPath)
	if err != nil {
		return err
	}

	// Parse configuration using utility functions
	content := string(data)
	sections := ParseSections(content)

	newConfig := NewSurgeConfig()

	// Parse each section
	if generalLines, ok := sections["General"]; ok {
		ParseGeneral(generalLines, newConfig.General)
	}
	if proxyLines, ok := sections["Proxy"]; ok {
		newConfig.Proxies = ParseProxies(proxyLines)
	}
	if groupLines, ok := sections["Proxy Group"]; ok {
		newConfig.ProxyGroups = ParseProxyGroups(groupLines)
	}
	if ruleLines, ok := sections["Rule"]; ok {
		newConfig.Rules = ParseRules(ruleLines)
	}
	if hostLines, ok := sections["Host"]; ok {
		newConfig.Hosts = ParseHosts(hostLines)
	}
	if urlRewriteLines, ok := sections["URL Rewrite"]; ok {
		newConfig.URLRewrites = ParseURLRewrites(urlRewriteLines)
	}
	if bodyRewriteLines, ok := sections["Body Rewrite"]; ok {
		newConfig.BodyRewrites = ParseBodyRewrites(bodyRewriteLines)
	}
	if mitmLines, ok := sections["MITM"]; ok {
		ParseMITM(mitmLines, newConfig.MITM)
	}

	m.config = newConfig
	return nil
}

// Save writes the configuration to file
func (m *ConfigManager) Save() error {
	m.mu.RLock()
	defer m.mu.RUnlock()

	content := m.serialize()
	return os.WriteFile(m.configPath, []byte(content), 0644)
}

// serialize converts the config struct back to surge.conf format
func (m *ConfigManager) serialize() string {
	var sb strings.Builder

	// [General]
	sb.WriteString("[General]\n")
	if m.config.General != nil {
		g := m.config.General
		if g.LogLevel != "" {
			sb.WriteString(fmt.Sprintf("loglevel = %s\n", g.LogLevel))
		}
		if len(g.DNSServer) > 0 {
			sb.WriteString(fmt.Sprintf("dns-server = %s\n", strings.Join(g.DNSServer, ", ")))
		}
		if len(g.EncryptedDNSServer) > 0 {
			sb.WriteString(fmt.Sprintf("encrypted-dns-server = %s\n", strings.Join(g.EncryptedDNSServer, ", ")))
		}
		if g.TestTimeout > 0 {
			sb.WriteString(fmt.Sprintf("test-timeout = %d\n", g.TestTimeout))
		}
		if g.InternetTestURL != "" {
			sb.WriteString(fmt.Sprintf("internet-test-url = %s\n", g.InternetTestURL))
		}
		if g.ProxyTestURL != "" {
			sb.WriteString(fmt.Sprintf("proxy-test-url = %s\n", g.ProxyTestURL))
		}
		if g.IPv6 {
			sb.WriteString("ipv6 = true\n")
		}
		if len(g.SkipProxy) > 0 {
			sb.WriteString(fmt.Sprintf("skip-proxy = %s\n", strings.Join(g.SkipProxy, ", ")))
		}
		if len(g.TunIncludedRoutes) > 0 {
			sb.WriteString(fmt.Sprintf("tun-included-routes = %s\n", strings.Join(g.TunIncludedRoutes, ", ")))
		}
		if len(g.TunExcludedRoutes) > 0 {
			sb.WriteString(fmt.Sprintf("tun-excluded-routes = %s\n", strings.Join(g.TunExcludedRoutes, ", ")))
		}
	}
	sb.WriteString("\n")

	// [Proxy]
	if len(m.config.Proxies) > 0 {
		sb.WriteString("[Proxy]\n")
		for _, proxy := range m.config.Proxies {
			sb.WriteString(serializeProxy(proxy))
		}
		sb.WriteString("\n")
	}

	// [Proxy Group]
	if len(m.config.ProxyGroups) > 0 {
		sb.WriteString("[Proxy Group]\n")
		for _, group := range m.config.ProxyGroups {
			sb.WriteString(serializeProxyGroup(group))
		}
		sb.WriteString("\n")
	}

	// [Rule]
	if len(m.config.Rules) > 0 {
		sb.WriteString("[Rule]\n")
		for _, rule := range m.config.Rules {
			sb.WriteString(serializeRule(rule))
		}
		sb.WriteString("\n")
	}

	// [Host]
	if len(m.config.Hosts) > 0 {
		sb.WriteString("[Host]\n")
		for _, host := range m.config.Hosts {
			sb.WriteString(fmt.Sprintf("%s = %s\n", host.Domain, host.Value))
		}
		sb.WriteString("\n")
	}

	// [URL Rewrite]
	if len(m.config.URLRewrites) > 0 {
		sb.WriteString("[URL Rewrite]\n")
		for _, rw := range m.config.URLRewrites {
			sb.WriteString(fmt.Sprintf("%s %s %s\n", rw.Regex, rw.Replacement, rw.Type))
		}
		sb.WriteString("\n")
	}

	// [MITM]
	if m.config.MITM != nil && m.config.MITM.Enabled {
		sb.WriteString("[MITM]\n")
		if len(m.config.MITM.Hostname) > 0 {
			sb.WriteString(fmt.Sprintf("hostname = %s\n", strings.Join(m.config.MITM.Hostname, ", ")))
		}
		sb.WriteString("\n")
	}

	return sb.String()
}

// GetConfig returns a copy of the current configuration
func (m *ConfigManager) GetConfig() *SurgeConfig {
	m.mu.RLock()
	defer m.mu.RUnlock()
	// TODO: Deep copy to prevent modifications
	return m.config
}

// GetGeneral returns the general configuration
func (m *ConfigManager) GetGeneral() *GeneralConfig {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.config.General
}

// UpdateGeneral updates the general configuration
func (m *ConfigManager) UpdateGeneral(cfg *GeneralConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.config.General = cfg
	return nil
}

// GetProxies returns all proxies
func (m *ConfigManager) GetProxies() []*ProxyConfig {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.config.Proxies
}

// GetProxy returns a specific proxy by name
func (m *ConfigManager) GetProxy(name string) (*ProxyConfig, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	for _, proxy := range m.config.Proxies {
		if proxy.Name == name {
			return proxy, nil
		}
	}
	return nil, fmt.Errorf("proxy not found: %s", name)
}

// AddProxy adds a new proxy
func (m *ConfigManager) AddProxy(proxy *ProxyConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Check for duplicates
	for _, p := range m.config.Proxies {
		if p.Name == proxy.Name {
			return fmt.Errorf("proxy already exists: %s", proxy.Name)
		}
	}

	m.config.Proxies = append(m.config.Proxies, proxy)
	return nil
}

// UpdateProxy updates an existing proxy
func (m *ConfigManager) UpdateProxy(name string, proxy *ProxyConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	for i, p := range m.config.Proxies {
		if p.Name == name {
			m.config.Proxies[i] = proxy
			return nil
		}
	}
	return fmt.Errorf("proxy not found: %s", name)
}

// DeleteProxy removes a proxy
func (m *ConfigManager) DeleteProxy(name string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	for i, p := range m.config.Proxies {
		if p.Name == name {
			m.config.Proxies = append(m.config.Proxies[:i], m.config.Proxies[i+1:]...)
			return nil
		}
	}
	return fmt.Errorf("proxy not found: %s", name)
}

// GetProxyGroups returns all proxy groups
func (m *ConfigManager) GetProxyGroups() []*ProxyGroupConfig {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.config.ProxyGroups
}

// GetProxyGroup returns a specific proxy group by name
func (m *ConfigManager) GetProxyGroup(name string) (*ProxyGroupConfig, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	for _, group := range m.config.ProxyGroups {
		if group.Name == name {
			return group, nil
		}
	}
	return nil, fmt.Errorf("proxy group not found: %s", name)
}

// AddProxyGroup adds a new proxy group
func (m *ConfigManager) AddProxyGroup(group *ProxyGroupConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Check for duplicates
	for _, g := range m.config.ProxyGroups {
		if g.Name == group.Name {
			return fmt.Errorf("proxy group already exists: %s", group.Name)
		}
	}

	m.config.ProxyGroups = append(m.config.ProxyGroups, group)
	return nil
}

// UpdateProxyGroup updates an existing proxy group
func (m *ConfigManager) UpdateProxyGroup(name string, group *ProxyGroupConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	for i, g := range m.config.ProxyGroups {
		if g.Name == name {
			m.config.ProxyGroups[i] = group
			return nil
		}
	}
	return fmt.Errorf("proxy group not found: %s", name)
}

// DeleteProxyGroup removes a proxy group
func (m *ConfigManager) DeleteProxyGroup(name string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	for i, g := range m.config.ProxyGroups {
		if g.Name == name {
			m.config.ProxyGroups = append(m.config.ProxyGroups[:i], m.config.ProxyGroups[i+1:]...)
			return nil
		}
	}
	return fmt.Errorf("proxy group not found: %s", name)
}

// GetRules returns all rules
func (m *ConfigManager) GetRules() []*RuleConfig {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.config.Rules
}

// AddRule adds a new rule at the end
func (m *ConfigManager) AddRule(rule *RuleConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.config.Rules = append(m.config.Rules, rule)
	return nil
}

// InsertRule inserts a rule at a specific index
func (m *ConfigManager) InsertRule(index int, rule *RuleConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if index < 0 || index > len(m.config.Rules) {
		return fmt.Errorf("invalid index: %d", index)
	}

	m.config.Rules = append(m.config.Rules[:index], append([]*RuleConfig{rule}, m.config.Rules[index:]...)...)
	return nil
}

// MoveRule moves a rule from fromIndex to toIndex
func (m *ConfigManager) MoveRule(fromIndex, toIndex int) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if fromIndex < 0 || fromIndex >= len(m.config.Rules) {
		return fmt.Errorf("invalid fromIndex: %d", fromIndex)
	}
	if toIndex < 0 || toIndex > len(m.config.Rules) {
		return fmt.Errorf("invalid toIndex: %d", toIndex)
	}

	rule := m.config.Rules[fromIndex]
	// Remove
	m.config.Rules = append(m.config.Rules[:fromIndex], m.config.Rules[fromIndex+1:]...)

	// Adjust toIndex if needed (if moving downwards)
	if toIndex > fromIndex {
		toIndex--
	}

	// Insert
	m.config.Rules = append(m.config.Rules[:toIndex], append([]*RuleConfig{rule}, m.config.Rules[toIndex:]...)...)
	return nil
}

// UpdateRule updates a rule at a specific index
func (m *ConfigManager) UpdateRule(index int, rule *RuleConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if index < 0 || index >= len(m.config.Rules) {
		return fmt.Errorf("invalid index: %d", index)
	}

	m.config.Rules[index] = rule
	return nil
}

// DeleteRule removes a rule at a specific index
func (m *ConfigManager) DeleteRule(index int) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if index < 0 || index >= len(m.config.Rules) {
		return fmt.Errorf("invalid index: %d", index)
	}

	m.config.Rules = append(m.config.Rules[:index], m.config.Rules[index+1:]...)
	return nil
}

// Helper serialization functions
func serializeProxy(p *ProxyConfig) string {
	var parts []string
	parts = append(parts, p.Type)
	parts = append(parts, p.Server)
	parts = append(parts, fmt.Sprintf("%d", p.Port))

	// Add parameters
	for k, v := range p.Parameters {
		parts = append(parts, fmt.Sprintf("%s=%s", k, v))
	}

	// Add standard fields
	if p.Username != "" {
		parts = append(parts, fmt.Sprintf("username=%s", p.Username))
	}
	if p.Password != "" {
		parts = append(parts, fmt.Sprintf("password=%s", p.Password))
	}
	if p.TLS {
		parts = append(parts, "tls=true")
	}
	if p.SNI != "" {
		parts = append(parts, fmt.Sprintf("sni=%s", p.SNI))
	}
	if p.SkipCertVerify {
		parts = append(parts, "skip-cert-verify=true")
	}

	return fmt.Sprintf("%s = %s\n", p.Name, strings.Join(parts, ", "))
}

func serializeProxyGroup(g *ProxyGroupConfig) string {
	var parts []string
	parts = append(parts, g.Type)
	parts = append(parts, g.Proxies...)

	if g.URL != "" {
		parts = append(parts, fmt.Sprintf("url=%s", g.URL))
	}
	if g.Interval > 0 {
		parts = append(parts, fmt.Sprintf("interval=%d", g.Interval))
	}
	if g.Selected != "" {
		parts = append(parts, fmt.Sprintf("selected=%s", g.Selected))
	}
	if g.EvaluateBeforeUse {
		parts = append(parts, "evaluate-before-use=true")
	}

	return fmt.Sprintf("%s = %s\n", g.Name, strings.Join(parts, ", "))
}

func serializeRule(r *RuleConfig) string {
	var parts []string
	parts = append(parts, r.Type)

	if r.Value != "" {
		parts = append(parts, r.Value)
	}
	if r.Policy != "" {
		parts = append(parts, r.Policy)
	}
	parts = append(parts, r.Params...)

	if r.NoResolve {
		parts = append(parts, "no-resolve")
	}

	line := strings.Join(parts, ",")
	if r.Comment != "" {
		line += " // " + r.Comment
	}
	return line + "\n"
}

// ========== Host Management ==========

// GetHosts returns all host mappings
func (m *ConfigManager) GetHosts() []*HostConfig {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.config.Hosts
}

// GetHost returns a specific host mapping by domain
func (m *ConfigManager) GetHost(domain string) (*HostConfig, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	for _, host := range m.config.Hosts {
		if host.Domain == domain {
			return host, nil
		}
	}
	return nil, fmt.Errorf("host not found: %s", domain)
}

// AddHost adds a new host mapping
func (m *ConfigManager) AddHost(host *HostConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Check for duplicates
	for _, h := range m.config.Hosts {
		if h.Domain == host.Domain {
			return fmt.Errorf("host already exists: %s", host.Domain)
		}
	}

	m.config.Hosts = append(m.config.Hosts, host)
	return nil
}

// UpdateHost updates an existing host mapping
func (m *ConfigManager) UpdateHost(domain string, host *HostConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	for i, h := range m.config.Hosts {
		if h.Domain == domain {
			m.config.Hosts[i] = host
			return nil
		}
	}
	return fmt.Errorf("host not found: %s", domain)
}

// DeleteHost removes a host mapping
func (m *ConfigManager) DeleteHost(domain string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	for i, h := range m.config.Hosts {
		if h.Domain == domain {
			m.config.Hosts = append(m.config.Hosts[:i], m.config.Hosts[i+1:]...)
			return nil
		}
	}
	return fmt.Errorf("host not found: %s", domain)
}

// ========== URL Rewrite Management ==========

// GetURLRewrites returns all URL rewrite rules
func (m *ConfigManager) GetURLRewrites() []*URLRewriteConfig {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.config.URLRewrites
}

// AddURLRewrite adds a new URL rewrite rule
func (m *ConfigManager) AddURLRewrite(rewrite *URLRewriteConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.config.URLRewrites = append(m.config.URLRewrites, rewrite)
	return nil
}

// UpdateURLRewrite updates a URL rewrite rule at a specific index
func (m *ConfigManager) UpdateURLRewrite(index int, rewrite *URLRewriteConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if index < 0 || index >= len(m.config.URLRewrites) {
		return fmt.Errorf("invalid index: %d", index)
	}

	m.config.URLRewrites[index] = rewrite
	return nil
}

// DeleteURLRewrite removes a URL rewrite rule at a specific index
func (m *ConfigManager) DeleteURLRewrite(index int) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if index < 0 || index >= len(m.config.URLRewrites) {
		return fmt.Errorf("invalid index: %d", index)
	}

	m.config.URLRewrites = append(m.config.URLRewrites[:index], m.config.URLRewrites[index+1:]...)
	return nil
}

// ========== Header Rewrite Management ==========
// Note: Header rewrites are stored in URLRewriteConfig with type="header"
// For now, we'll manage them separately through BodyRewriteConfig

// GetHeaderRewrites returns all header rewrite rules (using BodyRewrites for now)
func (m *ConfigManager) GetHeaderRewrites() []*BodyRewriteConfig {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.config.BodyRewrites
}

// AddHeaderRewrite adds a new header rewrite rule
func (m *ConfigManager) AddHeaderRewrite(rewrite *BodyRewriteConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.config.BodyRewrites = append(m.config.BodyRewrites, rewrite)
	return nil
}

// UpdateHeaderRewrite updates a header rewrite rule at a specific index
func (m *ConfigManager) UpdateHeaderRewrite(index int, rewrite *BodyRewriteConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if index < 0 || index >= len(m.config.BodyRewrites) {
		return fmt.Errorf("invalid index: %d", index)
	}

	m.config.BodyRewrites[index] = rewrite
	return nil
}

// DeleteHeaderRewrite removes a header rewrite rule at a specific index
func (m *ConfigManager) DeleteHeaderRewrite(index int) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if index < 0 || index >= len(m.config.BodyRewrites) {
		return fmt.Errorf("invalid index: %d", index)
	}

	m.config.BodyRewrites = append(m.config.BodyRewrites[:index], m.config.BodyRewrites[index+1:]...)
	return nil
}

// ========== MITM Management ==========

// GetMITM returns the MITM configuration
func (m *ConfigManager) GetMITM() *MITMConfig {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.config.MITM
}

// UpdateMITM updates the MITM configuration
func (m *ConfigManager) UpdateMITM(mitm *MITMConfig) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.config.MITM = mitm
	return nil
}

// ========== Configuration Validation ==========

// Validate checks if the configuration is valid
func (m *ConfigManager) Validate() error {
	m.mu.RLock()
	defer m.mu.RUnlock()

	// Validate General section
	if m.config.General == nil {
		return fmt.Errorf("general configuration is required")
	}

	// Validate Proxies - check for duplicate names
	proxyNames := make(map[string]bool)
	for _, proxy := range m.config.Proxies {
		if proxy.Name == "" {
			return fmt.Errorf("proxy name cannot be empty")
		}
		if proxyNames[proxy.Name] {
			return fmt.Errorf("duplicate proxy name: %s", proxy.Name)
		}
		proxyNames[proxy.Name] = true

		// Validate required fields
		if proxy.Type == "" {
			return fmt.Errorf("proxy type is required for: %s", proxy.Name)
		}
		if proxy.Server == "" {
			return fmt.Errorf("proxy server is required for: %s", proxy.Name)
		}
		if proxy.Port <= 0 || proxy.Port > 65535 {
			return fmt.Errorf("invalid port for proxy: %s", proxy.Name)
		}
	}

	// Validate Proxy Groups - check for duplicate names and valid proxy references
	groupNames := make(map[string]bool)
	for _, group := range m.config.ProxyGroups {
		if group.Name == "" {
			return fmt.Errorf("proxy group name cannot be empty")
		}
		if groupNames[group.Name] {
			return fmt.Errorf("duplicate proxy group name: %s", group.Name)
		}
		groupNames[group.Name] = true

		if group.Type == "" {
			return fmt.Errorf("proxy group type is required for: %s", group.Name)
		}
	}

	// Validate Rules
	for i, rule := range m.config.Rules {
		if rule.Type == "" {
			return fmt.Errorf("rule type is required at index: %d", i)
		}
		// FINAL rule doesn't need a value
		if rule.Type != "FINAL" && rule.Value == "" {
			return fmt.Errorf("rule value is required for type %s at index: %d", rule.Type, i)
		}
	}

	return nil
}

// ========== Configuration Backup and Restore ==========

// CreateBackup creates a backup of the current configuration file
func (m *ConfigManager) CreateBackup() error {
	m.mu.RLock()
	defer m.mu.RUnlock()

	data, err := os.ReadFile(m.configPath)
	if err != nil {
		return fmt.Errorf("failed to read config file: %v", err)
	}

	backupPath := m.configPath + ".backup"
	if err := os.WriteFile(backupPath, data, 0644); err != nil {
		return fmt.Errorf("failed to create backup: %v", err)
	}

	return nil
}

// RestoreBackup restores the configuration from backup
func (m *ConfigManager) RestoreBackup() error {
	backupPath := m.configPath + ".backup"
	data, err := os.ReadFile(backupPath)
	if err != nil {
		return fmt.Errorf("failed to read backup file: %v", err)
	}

	if err := os.WriteFile(m.configPath, data, 0644); err != nil {
		return fmt.Errorf("failed to restore backup: %v", err)
	}

	// Reload the configuration from the restored file
	return m.Load()
}

// GetConfigPath returns the configuration file path
func (m *ConfigManager) GetConfigPath() string {
	return m.configPath
}
