package config

import (
	"reflect"
	"testing"
)

func TestParseGeneral(t *testing.T) {
	lines := []string{
		"loglevel = notify",
		"ipv6 = true",
		"dns-server = 8.8.8.8, 1.1.1.1",
		"test-timeout = 10",
		"skip-proxy = 127.0.0.1, 192.168.0.0/16",
		"allow-wifi-access = true",
		"wifi-access-http-port = 8888",
		"replica = true",
		"interface = en0",
	}

	cfg := &GeneralConfig{}
	ParseGeneral(lines, cfg)

	if cfg.LogLevel != "notify" {
		t.Errorf("LogLevel = %v, want notify", cfg.LogLevel)
	}
	if !cfg.IPv6 {
		t.Errorf("IPv6 = %v, want true", cfg.IPv6)
	}
	if !reflect.DeepEqual(cfg.DNSServer, []string{"8.8.8.8", "1.1.1.1"}) {
		t.Errorf("DNSServer = %v, want [8.8.8.8 1.1.1.1]", cfg.DNSServer)
	}
	if cfg.TestTimeout != 10 {
		t.Errorf("TestTimeout = %v, want 10", cfg.TestTimeout)
	}
	if !reflect.DeepEqual(cfg.SkipProxy, []string{"127.0.0.1", "192.168.0.0/16"}) {
		t.Errorf("SkipProxy = %v, want [127.0.0.1 192.168.0.0/16]", cfg.SkipProxy)
	}
	if !cfg.AllowWifiAccess {
		t.Errorf("AllowWifiAccess = %v, want true", cfg.AllowWifiAccess)
	}
	if cfg.WifiAccessHTTPPort != 8888 {
		t.Errorf("WifiAccessHTTPPort = %v, want 8888", cfg.WifiAccessHTTPPort)
	}
	if !cfg.Replica {
		t.Errorf("Replica = %v, want true", cfg.Replica)
	}
	if cfg.Interface != "en0" {
		t.Errorf("Interface = %v, want en0", cfg.Interface)
	}
}

func TestParseGeneral_Defaults(t *testing.T) {
	lines := []string{}
	cfg := &GeneralConfig{
		TestTimeout: 5, // Default set by NewSurgeConfig
	}
	ParseGeneral(lines, cfg)

	if cfg.TestTimeout != 5 {
		t.Errorf("TestTimeout = %v, want 5 (default)", cfg.TestTimeout)
	}
}
