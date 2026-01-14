package benchmark

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"fmt" // Unused directly but maybe needed? Remove if unused.
	"math/big"
	"testing"
	"time"

	"github.com/surge-proxy/surge-go/internal/config"
	"github.com/surge-proxy/surge-go/internal/engine"
	"github.com/surge-proxy/surge-go/internal/mitm"
	"github.com/surge-proxy/surge-go/internal/rewrite"
	"github.com/surge-proxy/surge-go/internal/rule"
)

// --- Rule Matching Benchmarks ---

func BenchmarkRuleMatching_Domain(b *testing.B) {
	// Setup simple engine with domain rules
	cfg := &config.SurgeConfig{
		Rules: []*config.RuleConfig{
			{Type: "DOMAIN", Value: "google.com", Policy: "Proxy"},
			{Type: "DOMAIN-SUFFIX", Value: "apple.com", Policy: "Direct"},
			{Type: "FINAL", Value: "Final", Policy: "Final"},
		},
	}
	e := engine.NewEngine(cfg)
	e.RuleEngine = rule.NewEngine()
	e.RuleEngine.LoadRulesFromConfigs(cfg.Rules)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		e.MatchRule("https://google.com/foo", "192.168.1.1", "")
	}
}

func BenchmarkRuleMatching_CIDR(b *testing.B) {
	// Setup engine with CIDR rules
	cfg := &config.SurgeConfig{
		Rules: []*config.RuleConfig{
			{Type: "IP-CIDR", Value: "10.0.0.0/8", Policy: "Lan"},
			{Type: "IP-CIDR", Value: "192.168.0.0/16", Policy: "Lan"},
			{Type: "FINAL", Value: "Final", Policy: "Final"},
		},
	}
	e := engine.NewEngine(cfg)
	e.RuleEngine = rule.NewEngine()
	e.RuleEngine.LoadRulesFromConfigs(cfg.Rules)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		e.MatchRule("http://192.168.1.50", "", "") // Requires IP parsing in MatchRule
	}
}

// --- Rewriter Benchmarks ---

func BenchmarkURLRewrite_Regex(b *testing.B) {
	// Setup Regex Rewriter
	cfg := []*config.URLRewriteConfig{
		{Regex: "^https://www.google.com/search\\?q=(.*)", Replacement: "https://duckduckgo.com/?q=$1", Type: "302"},
	}
	rw, _ := rewrite.NewURLRewriter(cfg)
	url := "https://www.google.com/search?q=benchmark"

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		rw.Rewrite(url)
	}
}

func BenchmarkBodyRewrite_Simple(b *testing.B) {
	// Setup Body Rewriter
	cfg := []*config.BodyRewriteConfig{
		{Type: "http-response", URLRegex: "example.com", ReplacementOld: "foo", ReplacementNew: "bar", Mode: "text"},
	}
	bw, _ := rewrite.NewBodyRewriter(cfg)
	// 50KB Body
	body := make([]byte, 50*1024)
	copy(body, []byte("some text with foo inside repeated foo foo foo..."))
	url := "http://example.com/index.html"

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		bw.RewriteResponse(url, body)
	}
}

func BenchmarkBodyRewrite_Regex(b *testing.B) {
	// Setup Body Rewriter
	cfg := []*config.BodyRewriteConfig{
		{Type: "http-response", URLRegex: "example.com", ReplacementOld: "foo", ReplacementNew: "bar", Mode: "regex"},
	}
	bw, _ := rewrite.NewBodyRewriter(cfg)
	// 50KB Body
	body := make([]byte, 50*1024)
	copy(body, []byte("some text with foo inside repeated foo foo foo..."))
	url := "http://example.com/index.html"

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		bw.RewriteResponse(url, body)
	}
}

// --- MITM Benchmarks ---

func BenchmarkMITM_CertGeneration(b *testing.B) {
	// Setup MITM Manager without P12 (generates ephemeral CA if not provided, or we inject one)
	// Testing pure cert signing cost
	caCert, caKey, _ := generateDummyCA()

	m, _ := mitm.NewManager(&config.MITMConfig{Enabled: true})
	m.CertManager.SetCA(caCert, caKey)

	hello := &tls.ClientHelloInfo{
		ServerName: "www.google.com",
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		// This triggers caching, so it might be super fast after first?
		// We want to test generation. CertManager usually caches.
		// If caching is effective, this tests cache lookup.
		// To test generation, we'd need distinct hosts.
		host := fmt.Sprintf("random-%d.com", i)
		hello.ServerName = host
		m.GetCertificate(hello)
	}
}

// Helper to generate CA (copied from mitm_verify_test.go logic simplified)
func generateDummyCA() (*x509.Certificate, *rsa.PrivateKey, error) {
	priv, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return nil, nil, err
	}
	template := x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject:      pkix.Name{CommonName: "Bench CA"},
		NotBefore:    time.Now().Add(-1 * time.Hour),
		NotAfter:     time.Now().Add(1 * time.Hour),
		IsCA:         true,
		KeyUsage:     x509.KeyUsageCertSign | x509.KeyUsageDigitalSignature,
	}
	der, err := x509.CreateCertificate(rand.Reader, &template, &template, &priv.PublicKey, priv)
	if err != nil {
		return nil, nil, err
	}
	cert, err := x509.ParseCertificate(der)
	return cert, priv, err
}
