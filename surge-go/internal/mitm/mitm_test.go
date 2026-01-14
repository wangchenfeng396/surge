package mitm

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"math/big"
	"testing"
	"time"

	"github.com/surge-proxy/surge-go/internal/config"
)

// Helper to generate a dummy CA for testing without P12 file
func generateDummyCA() (*x509.Certificate, *rsa.PrivateKey, error) {
	priv, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return nil, nil, err
	}

	template := x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject: pkix.Name{
			CommonName: "Test CA",
		},
		NotBefore:             time.Now(),
		NotAfter:              time.Now().Add(time.Hour),
		KeyUsage:              x509.KeyUsageCertSign | x509.KeyUsageDigitalSignature,
		BasicConstraintsValid: true,
		IsCA:                  true,
	}

	der, err := x509.CreateCertificate(rand.Reader, &template, &template, &priv.PublicKey, priv)
	if err != nil {
		return nil, nil, err
	}

	cert, err := x509.ParseCertificate(der)
	return cert, priv, err
}

func TestCertManager_Sign(t *testing.T) {
	// Setup dummy CA
	caCert, caKey, err := generateDummyCA()
	if err != nil {
		t.Fatalf("Failed to generate dummy CA: %v", err)
	}

	cm := NewCertManager()
	cm.caCert = caCert
	cm.caKey = caKey

	targetHost := "example.com"
	cert, err := cm.signHost(targetHost)
	if err != nil {
		t.Fatalf("Failed to sign host: %v", err)
	}

	if len(cert.Certificate) == 0 {
		t.Fatal("Generated cert is empty")
	}

	parsed, err := x509.ParseCertificate(cert.Certificate[0])
	if err != nil {
		t.Fatal(err)
	}

	if parsed.Subject.CommonName != targetHost {
		t.Errorf("CN mismatch: got %v, want %v", parsed.Subject.CommonName, targetHost)
	}
}

func TestManager_ShouldIntercept(t *testing.T) {
	cfg := &config.MITMConfig{
		Enabled: true,
		Hostname: []string{
			"*.google.com",
			"example.com",
			"*suffix.net",
		},
		HostnameDisabled: []string{
			"mail.google.com",
		},
	}
	// Bypass NewManager P12 load for logic test
	mgr := &Manager{
		cfg:         cfg,
		CertManager: NewCertManager(),
	}

	tests := []struct {
		host string
		want bool
	}{
		{"www.google.com", true},
		{"google.com", false}, // *.google.com usually implies suffix .google.com in some proxy logic, but here "wildcard" logic in match() handles it.
		// My match logic: *google.com -> suffix google.com.
		// "google.com" ends with "google.com", so it matches.
		// Wait, *google.com = suffix google.com?
		// if pattern is *.google.com, suffix is .google.com usually?
		// My code: if prefix *, suffix = pattern[1:].
		// *.google.com -> .google.com.
		// "google.com" does NOT end with ".google.com".

		{"mail.google.com", false}, // Disabled
		{"example.com", true},
		{"test.example.com", false}, // Exact match example.com
		{"foo.suffix.net", true},
		{"other.net", false},
	}

	for _, tt := range tests {
		if got := mgr.ShouldIntercept(tt.host); got != tt.want {
			t.Errorf("ShouldIntercept(%q) = %v, want %v", tt.host, got, tt.want)
		}
	}
}
