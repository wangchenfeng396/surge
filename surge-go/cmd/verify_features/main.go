package main

import (
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/surge-proxy/surge-go/internal/config"
)

// ANSI colors
const (
	ColorReset  = "\033[0m"
	ColorRed    = "\033[31m"
	ColorGreen  = "\033[32m"
	ColorYellow = "\033[33m"
	ColorBlue   = "\033[34m"
)

func main() {
	log.SetFlags(0)
	fmt.Println(ColorBlue + "=== Starting Surge Config Feature Verification Suite ===" + ColorReset)
	fmt.Println("Simulating Parser against 'Maximum Complexity' Config...")

	cfg, err := config.ParseConfig(complexConfig)
	if err != nil {
		log.Fatalf(ColorRed+"FATAL: Failed to parse config: %v"+ColorReset, err)
	}

	// Run Checks
	passed := 0
	total := 0

	runCheck := func(name string, check func() error) {
		total++
		fmt.Printf("Checking %-50s ... ", name)
		if err := check(); err == nil {
			fmt.Println(ColorGreen + "PASS" + ColorReset)
			passed++
		} else {
			fmt.Printf(ColorRed+"FAIL (%v)"+ColorReset+"\n", err)
		}
	}

	// [General]
	runCheck("[General] TestTimeout", func() error {
		if cfg.General.TestTimeout != 5 {
			return fmt.Errorf("got %d", cfg.General.TestTimeout)
		}
		return nil
	})
	runCheck("[General] IPv6", func() error {
		if !cfg.General.IPv6 {
			return fmt.Errorf("expected true")
		}
		return nil
	})
	runCheck("[General] DNSServer", func() error {
		if len(cfg.General.DNSServer) != 2 || cfg.General.DNSServer[1] != "1.1.1.1" {
			return fmt.Errorf("got %v", cfg.General.DNSServer)
		}
		return nil
	})
	runCheck("[General] WiFi Access", func() error {
		if !cfg.General.AllowWifiAccess || cfg.General.WifiAccessHTTPPort != 6152 {
			return fmt.Errorf("wifi access mismatch")
		}
		return nil
	})

	// [Proxy]
	runCheck("[Proxy] VMess", func() error {
		p := findProxy(cfg.Proxies, "VMessNode")
		if p == nil {
			return fmt.Errorf("not found")
		}
		if p.Type != "vmess" || p.Server != "example.com" || p.Port != 443 || p.Username != "uuid-1234" {
			return fmt.Errorf("basic mismatch")
		}
		if p.Parameters["ws"] != "true" || p.Parameters["ws-path"] != "/ws" {
			return fmt.Errorf("params mismatch")
		}
		return nil
	})

	// [Proxy Group]
	runCheck("[Proxy Group] Select", func() error {
		g := findGroup(cfg.ProxyGroups, "SelectGroup")
		if g == nil {
			return fmt.Errorf("not found")
		}
		if g.Type != "select" || len(g.Proxies) != 2 {
			return fmt.Errorf("mismatch")
		}
		return nil
	})
	runCheck("[Proxy Group] Policy Path", func() error {
		g := findGroup(cfg.ProxyGroups, "SubGroup")
		if g == nil {
			return fmt.Errorf("not found")
		}
		if g.PolicyPath != "https://sub.example.com/list" || g.UpdateInterval != 86400 {
			return fmt.Errorf("mismatch")
		}
		return nil
	})
	runCheck("[Proxy Group] Regex Filter", func() error {
		g := findGroup(cfg.ProxyGroups, "SubGroup")
		if g.PolicyRegex != "(HK|US)" {
			return fmt.Errorf("got %s", g.PolicyRegex)
		}
		return nil
	})

	// [Rule]
	runCheck("[Rule] DOMAIN-SUFFIX", func() error {
		r := cfg.Rules[0]
		if r.Type != "DOMAIN-SUFFIX" || r.Value != "google.com" || r.Policy != "Proxy" {
			return fmt.Errorf("mismatch")
		}
		return nil
	})
	runCheck("[Rule] RULE-SET", func() error {
		r := findRule(cfg.Rules, "RULE-SET")
		if r == nil {
			return fmt.Errorf("not found")
		}
		if r.Value != "https://rules.example.com/list.list" || r.Policy != "Reject" {
			return fmt.Errorf("mismatch")
		}
		return nil
	})
	runCheck("[Rule] Comment", func() error {
		r := cfg.Rules[0]
		if r.Comment != "Google Strategy" {
			return fmt.Errorf("got '%s'", r.Comment)
		}
		return nil
	})
	runCheck("[Rule] No Resolve", func() error {
		r := findRule(cfg.Rules, "IP-CIDR")
		if r == nil || !r.NoResolve {
			return fmt.Errorf("no-resolve not parsed")
		}
		return nil
	})

	// [Host]
	runCheck("[Host] Mapping", func() error {
		if len(cfg.Hosts) == 0 || cfg.Hosts[0].Domain != "router.local" || cfg.Hosts[0].Value != "192.168.1.1" {
			return fmt.Errorf("mismatch")
		}
		return nil
	})

	// [URL Rewrite]
	runCheck("[URL Rewrite] Regex", func() error {
		if len(cfg.URLRewrites) == 0 || cfg.URLRewrites[0].Regex != "^http://www.google.cn" {
			return fmt.Errorf("mismatch")
		}
		return nil
	})

	// [Body Rewrite]
	runCheck("[Body Rewrite] Parser", func() error {
		if len(cfg.BodyRewrites) == 0 {
			return fmt.Errorf("not parsed")
		}
		br := cfg.BodyRewrites[0]
		// Expecting type=http-response, regex=https://mp.weixin.qq.com, replace...
		if br.Type != "http-response" || !strings.Contains(br.URLRegex, "weixin") {
			return fmt.Errorf("mismatch: %+v", br)
		}
		return nil
	})

	// [MITM]
	runCheck("[MITM] Config", func() error {
		if cfg.MITM == nil || !cfg.MITM.SkipServerCertVerify {
			return fmt.Errorf("mismatch")
		}
		if len(cfg.MITM.Hostname) != 2 {
			return fmt.Errorf("hostname list mismatch")
		}
		return nil
	})

	fmt.Printf("\n"+ColorBlue+"Summary: %d / %d Checks Passed"+ColorReset+"\n", passed, total)
	if passed == total {
		fmt.Println(ColorGreen + "ALL FEATURES VERIFIED SUCCESSFULLY" + ColorReset)
		os.Exit(0)
	} else {
		fmt.Println(ColorRed + "SOME CHECKS FAILED -- See details above" + ColorReset)
		os.Exit(1)
	}
}

func findProxy(list []*config.ProxyConfig, name string) *config.ProxyConfig {
	for _, p := range list {
		if p.Name == name {
			return p
		}
	}
	return nil
}

func findGroup(list []*config.ProxyGroupConfig, name string) *config.ProxyGroupConfig {
	for _, g := range list {
		if g.Name == name {
			return g
		}
	}
	return nil
}

func findRule(list []*config.RuleConfig, typeName string) *config.RuleConfig {
	for _, r := range list {
		if r.Type == typeName {
			return r
		}
	}
	return nil
}

var complexConfig = `
[General]
test-timeout = 5
ipv6 = true
dns-server = system, 1.1.1.1
allow-wifi-access = true
wifi-access-http-port = 6152
wifi-access-socks5-port = 6153
http-api-web-dashboard = true
loglevel = notify

[Proxy]
VMessNode = vmess, example.com, 443, username=uuid-1234, ws=true, ws-path=/ws, tls=true
Direct = direct

[Proxy Group]
SelectGroup = select, VMessNode, Direct
SubGroup = select, policy-path=https://sub.example.com/list, update-interval=86400, policy-regex-filter=(HK|US)

[Rule]
DOMAIN-SUFFIX, google.com, Proxy // Google Strategy
RULE-SET, https://rules.example.com/list.list, Reject
IP-CIDR, 192.168.0.0/16, DIRECT, no-resolve
FINAL, Direct

[Host]
router.local = 192.168.1.1
*.example.com = 1.2.3.4

[URL Rewrite]
^http://www.google.cn https://www.google.com header

[Body Rewrite]
http-response https://mp.weixin.qq.com/s script-response-body https://raw.githubusercontent.com/.../script.js

[MITM]
skip-server-cert-verify = true
hostname = *.google.com, *.apple.com
`
