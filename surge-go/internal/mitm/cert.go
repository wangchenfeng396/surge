package mitm

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"fmt"
	"math/big"
	"os"
	"sync"
	"time"

	"golang.org/x/crypto/pkcs12"
)

// CertManager manages CA and dynamic certificates
type CertManager struct {
	caCert *x509.Certificate
	caKey  interface{} // usually *rsa.PrivateKey or *ecdsa.PrivateKey

	certCache map[string]*tls.Certificate
	mu        sync.RWMutex
}

// NewCertManager creates a new manager
func NewCertManager() *CertManager {
	return &CertManager{
		certCache: make(map[string]*tls.Certificate),
	}
}

// LoadCAFromP12 loads CA from a PKCS#12 file
func (m *CertManager) LoadCAFromP12(path, password string) error {
	p12Data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("failed to read P12 file: %v", err)
	}

	// pkcs12.Decode returns private key, certificate, and potential extra certs via ToPEM or legacy Decode
	// Decode is deprecated but widely available.
	key, cert, err := pkcs12.Decode(p12Data, password)
	if err != nil {
		return fmt.Errorf("failed to decode P12: %v", err)
	}

	m.caKey = key
	m.caKey = key
	m.caCert = cert
	return nil
}

// SetCA sets the CA certificate and key directly
func (m *CertManager) SetCA(cert *x509.Certificate, key interface{}) {
	m.caCert = cert
	m.caKey = key
}

// GetCertificate generates or returns cached certificate for a given hostname
func (m *CertManager) GetCertificate(hello *tls.ClientHelloInfo) (*tls.Certificate, error) {
	host := hello.ServerName
	if host == "" {
		return nil, fmt.Errorf("SNI required for MITM")
	}

	m.mu.RLock()
	if cert, ok := m.certCache[host]; ok {
		m.mu.RUnlock()
		return cert, nil
	}
	m.mu.RUnlock()

	// Generate new cert
	cert, err := m.signHost(host)
	if err != nil {
		return nil, err
	}

	m.mu.Lock()
	m.certCache[host] = cert
	m.mu.Unlock()

	return cert, nil
}

func (m *CertManager) signHost(host string) (*tls.Certificate, error) {
	if m.caCert == nil || m.caKey == nil {
		return nil, fmt.Errorf("CA not loaded")
	}

	// Generate key for the server cert
	priv, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		return nil, err
	}

	// Create template
	serialNumberLimit := new(big.Int).Lsh(big.NewInt(1), 128)
	serialNumber, err := rand.Int(rand.Reader, serialNumberLimit)
	if err != nil {
		return nil, err
	}

	template := x509.Certificate{
		SerialNumber: serialNumber,
		Subject: pkix.Name{
			CommonName:   host,
			Organization: []string{"Surge Generated"},
		},
		NotBefore: time.Now().Add(-1 * time.Hour),
		NotAfter:  time.Now().Add(24 * 365 * time.Hour), // 1 year

		KeyUsage:              x509.KeyUsageKeyEncipherment | x509.KeyUsageDigitalSignature,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
		BasicConstraintsValid: true,
		DNSNames:              []string{host},
	}

	// Sign
	derBytes, err := x509.CreateCertificate(rand.Reader, &template, m.caCert, &priv.PublicKey, m.caKey)
	if err != nil {
		return nil, err
	}

	cert := &tls.Certificate{
		Certificate: [][]byte{derBytes},
		PrivateKey:  priv,
	}

	return cert, nil
}
