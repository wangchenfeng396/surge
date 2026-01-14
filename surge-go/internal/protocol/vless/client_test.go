package vless

import (
	"testing"

	"github.com/surge-proxy/surge-go/internal/protocol"
)

func TestConfig_Validate(t *testing.T) {
	tests := []struct {
		name    string
		config  *Config
		wantErr bool
	}{
		{
			name: "valid config",
			config: &Config{
				Server:     "example.com",
				Port:       443,
				UUID:       "12345678-1234-1234-1234-123456789012",
				Encryption: "none",
				Network:    "tcp",
				TLS:        true,
			},
			wantErr: false,
		},
		{
			name: "empty server",
			config: &Config{
				Port: 443,
				UUID: "12345678-1234-1234-1234-123456789012",
			},
			wantErr: true,
		},
		{
			name: "invalid port",
			config: &Config{
				Server: "example.com",
				Port:   99999,
				UUID:   "12345678-1234-1234-1234-123456789012",
			},
			wantErr: true,
		},
		{
			name: "empty UUID",
			config: &Config{
				Server: "example.com",
				Port:   443,
			},
			wantErr: true,
		},
		{
			name: "invalid UUID format",
			config: &Config{
				Server: "example.com",
				Port:   443,
				UUID:   "invalid-uuid",
			},
			wantErr: true,
		},
		{
			name: "invalid encryption",
			config: &Config{
				Server:     "example.com",
				Port:       443,
				UUID:       "12345678-1234-1234-1234-123456789012",
				Encryption: "aes-128-gcm",
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("Config.Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestFromProxyConfig(t *testing.T) {
	tests := []struct {
		name    string
		config  *protocol.ProxyConfig
		want    *Config
		wantErr bool
	}{
		{
			name: "basic vless config",
			config: &protocol.ProxyConfig{
				Name:   "test-vless",
				Type:   "vless",
				Server: "example.com",
				Port:   443,
				Options: map[string]interface{}{
					"uuid":       "12345678-1234-1234-1234-123456789012",
					"encryption": "none",
				},
			},
			want: &Config{
				Name:       "test-vless",
				Server:     "example.com",
				Port:       443,
				UUID:       "12345678-1234-1234-1234-123456789012",
				Encryption: "none",
				Network:    "tcp",
			},
			wantErr: false,
		},
		{
			name: "vless with websocket",
			config: &protocol.ProxyConfig{
				Name:   "test-vless-ws",
				Type:   "vless",
				Server: "example.com",
				Port:   443,
				Options: map[string]interface{}{
					"uuid":    "12345678-1234-1234-1234-123456789012",
					"ws":      true,
					"ws-path": "/vless",
					"tls":     true,
					"sni":     "example.com",
				},
			},
			want: &Config{
				Name:       "test-vless-ws",
				Server:     "example.com",
				Port:       443,
				UUID:       "12345678-1234-1234-1234-123456789012",
				Encryption: "none",
				Network:    "ws",
				Path:       "/vless",
				TLS:        true,
				SNI:        "example.com",
			},
			wantErr: false,
		},
		{
			name: "wrong protocol type",
			config: &protocol.ProxyConfig{
				Name:   "test-vmess",
				Type:   "vmess",
				Server: "example.com",
				Port:   443,
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := FromProxyConfig(tt.config)
			if (err != nil) != tt.wantErr {
				t.Errorf("FromProxyConfig() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if err != nil {
				return
			}

			// Compare relevant fields
			if got.Name != tt.want.Name {
				t.Errorf("Name = %v, want %v", got.Name, tt.want.Name)
			}
			if got.Server != tt.want.Server {
				t.Errorf("Server = %v, want %v", got.Server, tt.want.Server)
			}
			if got.Port != tt.want.Port {
				t.Errorf("Port = %v, want %v", got.Port, tt.want.Port)
			}
			if got.UUID != tt.want.UUID {
				t.Errorf("UUID = %v, want %v", got.UUID, tt.want.UUID)
			}
			if got.Network != tt.want.Network {
				t.Errorf("Network = %v, want %v", got.Network, tt.want.Network)
			}
		})
	}
}

func TestIsValidUUID(t *testing.T) {
	tests := []struct {
		uuid string
		want bool
	}{
		{"12345678-1234-1234-1234-123456789012", true},
		{"12345678123412341234123456789012", true},
		{"invalid-uuid", false},
		{"12345678-1234", false},
		{"", false},
		{"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", false},
	}

	for _, tt := range tests {
		t.Run(tt.uuid, func(t *testing.T) {
			if got := isValidUUID(tt.uuid); got != tt.want {
				t.Errorf("isValidUUID(%v) = %v, want %v", tt.uuid, got, tt.want)
			}
		})
	}
}

func TestUUIDToBytes(t *testing.T) {
	uuid := "12345678-1234-1234-1234-123456789012"
	bytes, err := UUIDToBytes(uuid)
	if err != nil {
		t.Fatalf("UUIDToBytes() error = %v", err)
	}
	if len(bytes) != 16 {
		t.Errorf("UUID bytes length = %d, want 16", len(bytes))
	}
}

func TestConfig_GetSNI(t *testing.T) {
	tests := []struct {
		name   string
		config *Config
		want   string
	}{
		{
			name: "with SNI",
			config: &Config{
				Server: "example.com",
				SNI:    "example.org",
			},
			want: "example.org",
		},
		{
			name: "with Host, no SNI",
			config: &Config{
				Server: "example.com",
				Host:   "example.net",
			},
			want: "example.net",
		},
		{
			name: "without SNI or Host",
			config: &Config{
				Server: "example.com",
			},
			want: "example.com",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.config.GetSNI()
			if got != tt.want {
				t.Errorf("GetSNI() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestNewClient(t *testing.T) {
	config := &Config{
		Name:       "test",
		Server:     "example.com",
		Port:       443,
		UUID:       "12345678-1234-1234-1234-123456789012",
		Encryption: "none",
		Network:    "tcp",
		TLS:        true,
	}

	client, err := NewClient(config)
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}

	if client.Name() != "test" {
		t.Errorf("Name() = %v, want test", client.Name())
	}

	if client.Type() != "vless" {
		t.Errorf("Type() = %v, want vless", client.Type())
	}
}

func TestNewClientFromProxyConfig(t *testing.T) {
	cfg := &protocol.ProxyConfig{
		Name:   "test-vless",
		Type:   "vless",
		Server: "example.com",
		Port:   443,
		Options: map[string]interface{}{
			"uuid":       "12345678-1234-1234-1234-123456789012",
			"encryption": "none",
			"ws":         true,
			"ws-path":    "/vless",
			"tls":        true,
			"sni":        "example.com",
		},
	}

	client, err := NewClientFromProxyConfig(cfg)
	if err != nil {
		t.Fatalf("NewClientFromProxyConfig() error = %v", err)
	}

	if client.Name() != "test-vless" {
		t.Errorf("Name() = %v, want test-vless", client.Name())
	}

	if client.Type() != "vless" {
		t.Errorf("Type() = %v, want vless", client.Type())
	}
}
