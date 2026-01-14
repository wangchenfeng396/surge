package config

// Parse utilities exported for use by ConfigManager

import (
	"fmt"
	"strings"
)

// ParseSections splits config content into sections
func ParseSections(content string) map[string][]string {
	sections := make(map[string][]string)
	var currentSection string
	var currentLines []string

	for _, line := range strings.Split(content, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			if currentSection != "" {
				sections[currentSection] = currentLines
			}
			currentSection = strings.Trim(line, "[]")
			currentLines = []string{}
		} else if currentSection != "" {
			currentLines = append(currentLines, line)
		}
	}
	if currentSection != "" {
		sections[currentSection] = currentLines
	}
	return sections
}

// ParseProxies parses [Proxy] section
func ParseProxies(lines []string) []*ProxyConfig {
	var proxies []*ProxyConfig

	for _, line := range lines {
		if strings.TrimSpace(line) == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}

		name := strings.TrimSpace(parts[0])
		cfgStr := strings.TrimSpace(parts[1])

		proxy := ParseSingleProxy(name, cfgStr)
		if proxy != nil {
			proxies = append(proxies, proxy)
		}
	}
	return proxies
}

func ParseSingleProxy(name, cfgStr string) *ProxyConfig {
	parts := splitConfig(cfgStr)
	if len(parts) < 2 {
		return nil
	}

	proxy := &ProxyConfig{
		Name:       name,
		Type:       parts[0],
		Parameters: make(map[string]string),
	}

	if len(parts) >= 3 {
		proxy.Server = parts[1]
		var port int
		if _, err := fmt.Sscanf(parts[2], "%d", &port); err == nil {
			proxy.Port = port
		}
	}

	// Parse parameters
	for i := 1; i < len(parts); i++ {
		kv := strings.SplitN(parts[i], "=", 2)
		if len(kv) == 2 {
			key := strings.TrimSpace(kv[0])
			val := strings.TrimSpace(kv[1])
			proxy.Parameters[key] = val

			// Map common fields
			switch key {
			case "username":
				proxy.Username = val
			case "password":
				proxy.Password = val
			case "tls":
				proxy.TLS = val == "true"
			case "sni":
				proxy.SNI = val
			case "skip-cert-verify":
				proxy.SkipCertVerify = val == "true"
			case "tfo":
				proxy.TFO = val == "true"
			case "udp":
				proxy.UDP = val == "true"
			}
		}
	}
	return proxy
}

// ParseProxyGroups parses [Proxy Group] section
func ParseProxyGroups(lines []string) []*ProxyGroupConfig {
	var groups []*ProxyGroupConfig
	for _, line := range lines {
		if strings.TrimSpace(line) == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}

		name := strings.TrimSpace(parts[0])
		cfg := strings.TrimSpace(parts[1])
		partsList := splitConfig(cfg)
		if len(partsList) == 0 {
			continue
		}

		group := &ProxyGroupConfig{
			Name:    name,
			Type:    partsList[0],
			Proxies: make([]string, 0),
		}

		for i := 1; i < len(partsList); i++ {
			part := partsList[i]
			if strings.Contains(part, "=") {
				kv := strings.SplitN(part, "=", 2)
				key := strings.TrimSpace(kv[0])
				val := strings.TrimSpace(kv[1])
				switch key {
				case "url":
					group.URL = val
				case "interval":
					group.Interval = mustInt(val)
				case "policy-path":
					group.PolicyPath = val
				case "policy-regex-filter":
					group.PolicyRegex = val
				case "update-interval":
					group.UpdateInterval = mustInt(val)
				case "include-all-proxies":
					group.IncludeAll = val == "true" || val == "1"
				case "hidden":
					group.Hidden = val == "true" || val == "1"
				case "no-alert":
					group.NoAlert = val == "true" || val == "1"
				case "selected":
					group.Selected = val
				case "evaluate-before-use":
					group.EvaluateBeforeUse = val == "true" || val == "1"
				}
			} else {
				group.Proxies = append(group.Proxies, part)
			}
		}
		groups = append(groups, group)
	}
	return groups
}

// ParseRules parses[Rule] section
func ParseRules(lines []string) []*RuleConfig {
	var rules []*RuleConfig
	for _, line := range lines {
		comment := ""
		if idx := strings.Index(line, "//"); idx != -1 {
			if idx > 0 && line[idx-1] == ':' {
				if cIdx := strings.Index(line, " //"); cIdx != -1 {
					comment = strings.TrimSpace(line[cIdx+3:])
					line = line[:cIdx]
				}
			} else {
				comment = strings.TrimSpace(line[idx+2:])
				line = line[:idx]
			}
		}
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := splitConfig(line)
		if len(parts) < 2 {
			continue
		}

		rule := &RuleConfig{
			Type:    parts[0],
			Value:   parts[1],
			Comment: comment,
			Params:  make([]string, 0),
			Enabled: true,
		}

		if rule.Type == "FINAL" {
			// FINAL,Proxy,dns-failed
			// parts[0]=FINAL, parts[1]=Proxy, parts[2]=dns-failed
			rule.Policy = parts[1]
			rule.Value = ""
			if len(parts) > 2 {
				for i := 2; i < len(parts); i++ {
					rule.Params = append(rule.Params, parts[i])
				}
			}
		} else if len(parts) > 2 {
			rule.Policy = parts[2]
			for i := 3; i < len(parts); i++ {
				if parts[i] == "no-resolve" {
					rule.NoResolve = true
				} else {
					rule.Params = append(rule.Params, parts[i])
				}
			}
		}
		rules = append(rules, rule)
	}
	return rules
}

// ParseHosts parses [Host] section
func ParseHosts(lines []string) []*HostConfig {
	var hosts []*HostConfig
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		hosts = append(hosts, &HostConfig{
			Domain: strings.TrimSpace(parts[0]),
			Value:  strings.TrimSpace(parts[1]),
		})
	}
	return hosts
}

// ParseURLRewrites parses [URL Rewrite] section
func ParseURLRewrites(lines []string) []*URLRewriteConfig {
	var rewrites []*URLRewriteConfig
	for _, line := range lines {
		if idx := strings.Index(line, "//"); idx != -1 {
			if !(idx > 0 && line[idx-1] == ':') {
				line = line[:idx]
			} else if cIdx := strings.Index(line, " //"); cIdx != -1 {
				line = line[:cIdx]
			}
		}
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.Fields(line)
		if len(parts) < 3 {
			continue
		}

		rewrites = append(rewrites, &URLRewriteConfig{
			Regex:       parts[0],
			Replacement: parts[1],
			Type:        parts[2],
		})
	}
	return rewrites
}

// ParseBodyRewrites parses [Body Rewrite] section
func ParseBodyRewrites(lines []string) []*BodyRewriteConfig {
	var rewrites []*BodyRewriteConfig
	for _, line := range lines {
		if idx := strings.Index(line, "//"); idx != -1 {
			if idx > 0 && line[idx-1] == ':' {
				if cIdx := strings.Index(line, " //"); cIdx != -1 {
					line = line[:cIdx]
				}
			} else {
				line = line[:idx]
			}
		}
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.Fields(line)
		if len(parts) < 2 {
			continue
		}

		br := &BodyRewriteConfig{
			Type:     parts[0],
			URLRegex: parts[1],
		}

		if len(parts) > 2 {
			br.ReplacementOld = parts[2]
		}
		if len(parts) > 3 {
			br.ReplacementNew = parts[3]
		}
		if len(parts) > 4 {
			br.Mode = parts[4]
		}

		rewrites = append(rewrites, br)
	}
	return rewrites
}

// ParseMITM parses [MITM] section
func ParseMITM(lines []string, cfg *MITMConfig) {
	for _, line := range lines {
		if idx := strings.Index(line, "="); idx != -1 {
			key := strings.TrimSpace(line[:idx])
			val := strings.TrimSpace(line[idx+1:])
			switch key {
			case "skip-server-cert-verify":
				cfg.SkipServerCertVerify = val == "true"
			case "tcp-connection":
				cfg.TCPConnection = val == "true"
			case "h2":
				cfg.H2 = val == "true"
			case "hostname":
				cfg.Hostname = splitList(val)
			}
		}
	}
}

// ParseConfig parses the complete Surge configuration
func ParseConfig(content string) (*SurgeConfig, error) {
	cfg := NewSurgeConfig()
	sections := ParseSections(content)

	if lines, ok := sections["General"]; ok {
		ParseGeneral(lines, cfg.General)
	}

	if lines, ok := sections["Proxy"]; ok {
		cfg.Proxies = ParseProxies(lines)
	}

	// Support both "Proxy" and "Proxies"? usually Surge uses "Proxy"

	if lines, ok := sections["Proxy Group"]; ok {
		cfg.ProxyGroups = ParseProxyGroups(lines)
	}

	if lines, ok := sections["Rule"]; ok {
		cfg.Rules = ParseRules(lines)
	}

	if lines, ok := sections["Host"]; ok {
		cfg.Hosts = ParseHosts(lines)
	}

	if lines, ok := sections["URL Rewrite"]; ok {
		cfg.URLRewrites = ParseURLRewrites(lines)
	}

	if lines, ok := sections["MITM"]; ok {
		ParseMITM(lines, cfg.MITM)
	}

	// Body Rewrite section?
	// ParseBodyRewrites is available but not called here?
	if lines, ok := sections["Body Rewrite"]; ok {
		cfg.BodyRewrites = ParseBodyRewrites(lines)
	}

	return cfg, nil
}

// Helper functions moved to util.go
