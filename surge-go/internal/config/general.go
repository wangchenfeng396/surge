package config

import (
	"strings"
)

// GeneralConfig represents the [General] section
type GeneralConfig struct {
	TestTimeout                    int      `json:"test_timeout"`
	UDPPriority                    bool     `json:"udp_priority"`
	InternetTestURL                string   `json:"internet_test_url"`
	ProxyTestURL                   string   `json:"proxy_test_url"`
	GeoIPMaxmindURL                string   `json:"geoip_maxmind_url"`
	IPv6                           bool     `json:"ipv6"`
	DNSServer                      []string `json:"dns_server"`
	EncryptedDNSServer             []string `json:"encrypted_dns_server"`
	ShowErrorPageForReject         bool     `json:"show_error_page_for_reject"`
	SkipProxy                      []string `json:"skip_proxy"`
	AllowWifiAccess                bool     `json:"allow_wifi_access"`
	WifiAccessHTTPPort             int      `json:"wifi_access_http_port"`
	WifiAccessSOCKS5Port           int      `json:"wifi_access_socks5_port"`
	AllowHotspotAccess             bool     `json:"allow_hotspot_access"`
	WifiAssist                     bool     `json:"wifi_assist"`
	HTTPAPI                        string   `json:"http_api"`
	HttpApiTls                     bool     `json:"http_api_tls"`
	HttpApiWebDashboard            bool     `json:"http_api_web_dashboard"`
	AllHybrid                      bool     `json:"all_hybrid"`
	ExcludeSimpleHostnames         bool     `json:"exclude_simple_hostnames"`
	ReadEtcHosts                   bool     `json:"read_etc_hosts"`
	LogLevel                       string   `json:"loglevel"`
	AlwaysRealIP                   []string `json:"always_real_ip"`
	DisableGeoIPDBAutoUpdate       bool     `json:"disable_geoip_db_auto_update"`
	UDPPolicyNotSupportedBehaviour string   `json:"udp_policy_not_supported_behaviour"`
	TunIncludedRoutes              []string `json:"tun_included_routes"`
	TunExcludedRoutes              []string `json:"tun_excluded_routes"`
	Replica                        bool     `json:"replica"`
	Interface                      string   `json:"interface"`
}

// ParseGeneral parses General configuration
func ParseGeneral(lines []string, cfg *GeneralConfig) {
	for _, line := range lines {
		if idx := strings.Index(line, "="); idx != -1 {
			key := strings.TrimSpace(line[:idx])
			value := strings.TrimSpace(line[idx+1:])

			switch key {
			case "test-timeout":
				cfg.TestTimeout = mustInt(value)
			case "udp-priority":
				cfg.UDPPriority = value == "true"
			case "internet-test-url":
				cfg.InternetTestURL = value
			case "proxy-test-url":
				cfg.ProxyTestURL = value
			case "geoip-maxmind-url":
				cfg.GeoIPMaxmindURL = value
			case "ipv6":
				cfg.IPv6 = value == "true"
			case "dns-server":
				cfg.DNSServer = splitList(value)
			case "encrypted-dns-server":
				cfg.EncryptedDNSServer = splitList(value)
			case "show-error-page-for-reject":
				cfg.ShowErrorPageForReject = value == "true"
			case "skip-proxy":
				cfg.SkipProxy = splitList(value)
			case "allow-wifi-access":
				cfg.AllowWifiAccess = value == "true"
			case "wifi-access-http-port":
				cfg.WifiAccessHTTPPort = mustInt(value)
			case "wifi-access-socks5-port":
				cfg.WifiAccessSOCKS5Port = mustInt(value)
			case "allow-hotspot-access":
				cfg.AllowHotspotAccess = value == "true"
			case "wifi-assist":
				cfg.WifiAssist = value == "true"
			case "http-api":
				cfg.HTTPAPI = value
			case "http-api-tls":
				cfg.HttpApiTls = value == "true"
			case "http-api-web-dashboard":
				cfg.HttpApiWebDashboard = value == "true"
			case "loglevel":
				cfg.LogLevel = value
			case "always-real-ip":
				cfg.AlwaysRealIP = splitList(value)
			case "tun-included-routes":
				cfg.TunIncludedRoutes = splitList(value)
			case "tun-excluded-routes":
				cfg.TunExcludedRoutes = splitList(value)
			case "udp-policy-not-supported-behaviour":
				cfg.UDPPolicyNotSupportedBehaviour = value
			case "disable-geoip-db-auto-update":
				cfg.DisableGeoIPDBAutoUpdate = value == "true"
			case "exclude-simple-hostnames":
				cfg.ExcludeSimpleHostnames = value == "true"
			case "read-etc-hosts":
				cfg.ReadEtcHosts = value == "true"
			case "all-hybrid":
				cfg.AllHybrid = value == "true"
			case "replica":
				cfg.Replica = value == "true"
			case "interface":
				cfg.Interface = value
			}
		}
	}
}
