package main_test

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"fmt"
	"math/big"
	"net/http"
	"net/url"
	"testing"
	"time"

	"github.com/surge-proxy/surge-go/internal/config"
	"github.com/surge-proxy/surge-go/internal/engine"
	"github.com/surge-proxy/surge-go/internal/server"
)

// Helper to generate CA
func generateCA(t *testing.T) (*x509.Certificate, *rsa.PrivateKey) {
	priv, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}

	template := x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject: pkix.Name{
			CommonName: "Surge Test CA",
		},
		NotBefore:             time.Now().Add(-24 * time.Hour),
		NotAfter:              time.Now().Add(24 * time.Hour),
		KeyUsage:              x509.KeyUsageCertSign | x509.KeyUsageDigitalSignature,
		BasicConstraintsValid: true,
		IsCA:                  true,
	}

	der, err := x509.CreateCertificate(rand.Reader, &template, &template, &priv.PublicKey, priv)
	if err != nil {
		t.Fatal(err)
	}

	cert, err := x509.ParseCertificate(der)
	if err != nil {
		t.Fatal(err)
	}
	return cert, priv
}

func TestMITM(t *testing.T) {
	caCert, caKey := generateCA(t)

	// 1. Config with MITM enabled
	cfg := config.NewSurgeConfig()
	cfg.General = &config.GeneralConfig{LogLevel: "info"}
	cfg.MITM = &config.MITMConfig{
		Enabled:              true,
		Hostname:             []string{"*google.com"}, // Intercept google.com
		SkipServerCertVerify: true,
	}

	cfg.URLRewrites = []*config.URLRewriteConfig{
		{
			Regex:       "^https://www.google.com/mitm",
			Replacement: "https://success.com",
			Type:        "302",
		},
	}

	// 2. Start Engine
	eng := engine.NewEngine(cfg)
	if err := eng.Start(); err != nil {
		t.Fatalf("Failed to start engine: %v", err)
	}
	defer eng.Stop()

	// Inject CA
	if eng.MITMManager != nil && eng.MITMManager.CertManager != nil {
		eng.MITMManager.CertManager.SetCA(caCert, caKey)
	} else {
		t.Fatal("MITMManager or CertManager not initialized")
	}

	// 3. Start HTTP Server
	port := 18889
	addr := fmt.Sprintf("127.0.0.1:%d", port)

	// Make sure we pass the same manager instance
	var rewriter server.Rewriter = eng.URLRewriter
	var mitm server.MITM = eng.MITMManager

	srv := server.NewHTTPServer(addr, eng, rewriter, nil, mitm)
	go func() {
		srv.Start()
	}()
	defer srv.Shutdown(context.Background())

	time.Sleep(200 * time.Millisecond)

	// 4. Client with Custom CA Trust
	rootCAs := x509.NewCertPool()
	rootCAs.AddCert(caCert)

	proxyURL, _ := url.Parse(fmt.Sprintf("http://%s", addr))
	client := &http.Client{
		Transport: &http.Transport{
			Proxy: http.ProxyURL(proxyURL),
			TLSClientConfig: &tls.Config{
				RootCAs:            rootCAs,
				InsecureSkipVerify: true, // Relaxed
			},
		},
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}

	// 5. Verify MITM + Rewrite
	resp, err := client.Get("https://www.google.com/mitm")
	if err != nil {
		t.Fatalf("Request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 302 {
		t.Errorf("Expected 302, got %d", resp.StatusCode)
	}
	loc := resp.Header.Get("Location")
	if loc != "https://success.com" {
		t.Errorf("Expected https://success.com, got %s", loc)
	}

	// Verify Certificate was indeed ours
	if resp.TLS != nil && len(resp.TLS.PeerCertificates) > 0 {
		issuer := resp.TLS.PeerCertificates[0].Issuer.CommonName
		if issuer != "Surge Test CA" {
			t.Errorf("Expected Issuer 'Surge Test CA', got '%s'", issuer)
		}
	} else {
		t.Error("TPS info missing, MITM might not have happened")
	}
}
