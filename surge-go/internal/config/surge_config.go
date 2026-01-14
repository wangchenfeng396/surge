package config

// SurgeConfig represents the complete Surge configuration
type SurgeConfig struct {
	General      *GeneralConfig
	Proxies      []*ProxyConfig
	ProxyGroups  []*ProxyGroupConfig
	Rules        []*RuleConfig
	Hosts        []*HostConfig
	URLRewrites  []*URLRewriteConfig
	BodyRewrites []*BodyRewriteConfig
	MITM         *MITMConfig
}

// ProxyConfig represents a single proxy in [Proxy] section
type ProxyConfig struct {
	Name           string            `json:"name"`
	Type           string            `json:"type"`
	Server         string            `json:"server"`
	Port           int               `json:"port"`
	Username       string            `json:"username"`
	Password       string            `json:"password"`
	Auth           bool              `json:"auth"`
	TLS            bool              `json:"tls"`
	SNI            string            `json:"sni"`
	SkipCertVerify bool              `json:"skip_cert_verify"`
	TFO            bool              `json:"tfo"`
	UDP            bool              `json:"udp"`
	Parameters     map[string]string `json:"parameters"`
}

// ProxyGroupConfig represents a single group in [Proxy Group] section
type ProxyGroupConfig struct {
	Name              string   `json:"name"`
	Type              string   `json:"type"` // select, url-test, load-balance, fallback, ssid, etc.
	Proxies           []string `json:"proxies"`
	URL               string   `json:"url"`
	Interval          int      `json:"interval"`
	Tolerance         int      `json:"tolerance"`
	Timeout           int      `json:"timeout"`
	UpdateInterval    int      `json:"update_interval"`
	PolicyPath        string   `json:"policy_path"`
	PolicyRegex       string   `json:"policy_regex_filter"`
	IncludeAll        bool     `json:"include_all_proxies"`
	Hidden            bool     `json:"hidden"`
	NoAlert           bool     `json:"no_alert"`
	Selected          string   `json:"selected"` // Persist selected proxy
	EvaluateBeforeUse bool     `json:"evaluate_before_use"`
}

// RuleConfig represents a single rule in [Rule] section
type RuleConfig struct {
	Type           string   `json:"type"`
	Value          string   `json:"value"`
	Policy         string   `json:"policy"`
	Params         []string `json:"params"`
	NoResolve      bool     `json:"no_resolve"`
	UpdateInterval int      `json:"update_interval"`
	Comment        string   `json:"comment"`
	Enabled        bool     `json:"enabled"`
}

// HostConfig represents a single item in [Host] section
type HostConfig struct {
	Domain string `json:"domain"`
	Value  string `json:"value"` // IP, server:IP, alias, etc.
}

// URLRewriteConfig represents a single item in [URL Rewrite] section
type URLRewriteConfig struct {
	Type        string `json:"type"` // header, 302, 307, reject, etc.
	Regex       string `json:"regex"`
	Replacement string `json:"replacement"`
	Mode        string `json:"mode"`
}

// BodyRewriteConfig represents a single item in [Body Rewrite] section
type BodyRewriteConfig struct {
	Type           string `json:"type"` // http-request, http-response
	URLRegex       string `json:"url_regex"`
	ReplacementOld string `json:"replacement_old"`
	ReplacementNew string `json:"replacement_new"`
	Mode           string `json:"mode"` // simple, regex
}

// MITMConfig represents the [MITM] section
type MITMConfig struct {
	Enabled              bool     `json:"enabled"`
	SkipServerCertVerify bool     `json:"skip_server_cert_verify"`
	TCPConnection        bool     `json:"tcp_connection"`
	H2                   bool     `json:"h2"`
	Hostname             []string `json:"hostname"`
	HostnameDisabled     []string `json:"hostname_disabled"`
	AutoQUICBlock        bool     `json:"auto_quic_block"`
	CAPassphrase         string   `json:"ca_passphrase"`
	CAP12                string   `json:"ca_p12"`
}

// NewSurgeConfig creates a default SurgeConfig
func NewSurgeConfig() *SurgeConfig {
	return &SurgeConfig{
		General: &GeneralConfig{
			TestTimeout:            5,
			LogLevel:               "notify",
			ExcludeSimpleHostnames: true,
			HttpApiWebDashboard:    true,
		},
		Proxies:      make([]*ProxyConfig, 0),
		ProxyGroups:  make([]*ProxyGroupConfig, 0),
		Rules:        make([]*RuleConfig, 0),
		Hosts:        make([]*HostConfig, 0),
		URLRewrites:  make([]*URLRewriteConfig, 0),
		BodyRewrites: make([]*BodyRewriteConfig, 0),
		MITM:         &MITMConfig{},
	}
}
