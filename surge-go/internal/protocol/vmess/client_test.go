package vmess

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
				Server:   "example.com",
				Port:     443,
				UUID:     "12345678-1234-1234-1234-123456789012",
				AlterID:  0,
				Security: SecurityAES128GCM,
				Network:  "tcp",
				TLS:      true,
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
			name: "basic vmess config",
			config: &protocol.ProxyConfig{
				Name:   "test-vmess",
				Type:   "vmess",
				Server: "example.com",
				Port:   443,
				Options: map[string]interface{}{
					"uuid":     "12345678-1234-1234-1234-123456789012",
					"alterId":  64,
					"security": "aes-128-gcm",
				},
			},
			want: &Config{
				Name:     "test-vmess",
				Server:   "example.com",
				Port:     443,
				UUID:     "12345678-1234-1234-1234-123456789012",
				AlterID:  64,
				Security: SecurityAES128GCM,
				Network:  "tcp",
				AEAD:     false, // alterId > 0, so AEAD is false
			},
			wantErr: false,
		},
		{
			name: "vmess with websocket",
			config: &protocol.ProxyConfig{
				Name:   "test-vmess-ws",
				Type:   "vmess",
				Server: "example.com",
				Port:   443,
				Options: map[string]interface{}{
					"uuid":    "12345678-1234-1234-1234-123456789012",
					"ws":      true,
					"ws-path": "/ws",
					"tls":     true,
					"sni":     "example.com",
				},
			},
			want: &Config{
				Name:     "test-vmess-ws",
				Server:   "example.com",
				Port:     443,
				UUID:     "12345678-1234-1234-1234-123456789012",
				AlterID:  0,
				Security: SecurityAuto,
				Network:  "ws",
				Path:     "/ws",
				TLS:      true,
				SNI:      "example.com",
				AEAD:     true,
			},
			wantErr: false,
		},
		{
			name: "wrong protocol type",
			config: &protocol.ProxyConfig{
				Name:   "test-trojan",
				Type:   "trojan",
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

func TestNewClient(t *testing.T) {
	config := &Config{
		Name:     "test",
		Server:   "example.com",
		Port:     443,
		UUID:     "12345678-1234-1234-1234-123456789012",
		AlterID:  0,
		Security: SecurityAES128GCM,
		Network:  "tcp",
		TLS:      true,
		AEAD:     true,
	}

	client, err := NewClient(config)
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}

	if client.Name() != "test" {
		t.Errorf("Name() = %v, want test", client.Name())
	}

	if client.Type() != "vmess" {
		t.Errorf("Type() = %v, want vmess", client.Type())
	}
}

func TestNewClientFromProxyConfig(t *testing.T) {
	cfg := &protocol.ProxyConfig{
		Name:   "test-vmess",
		Type:   "vmess",
		Server: "example.com",
		Port:   443,
		Options: map[string]interface{}{
			"uuid":       "12345678-1234-1234-1234-123456789012",
			"security":   "aes-128-gcm",
			"ws":         true,
			"ws-path":    "/ws",
			"tls":        true,
			"sni":        "example.com",
			"vmess-aead": true,
		},
	}

	client, err := NewClientFromProxyConfig(cfg)
	if err != nil {
		t.Fatalf("NewClientFromProxyConfig() error = %v", err)
	}

	if client.Name() != "test-vmess" {
		t.Errorf("Name() = %v, want test-vmess", client.Name())
	}

	if client.Type() != "vmess" {
		t.Errorf("Type() = %v, want vmess", client.Type())
	}
}

func TestCreateRequestHeader(t *testing.T) {
	uuid, _ := UUIDToBytes("12345678-1234-1234-1234-123456789012")
	header := CreateRequestHeader(CommandTCP, "example.com", 443, uuid, SecurityAES128GCM)

	if header.Version != 1 {
		t.Errorf("Version = %d, want 1", header.Version)
	}
	if header.Command != CommandTCP {
		t.Errorf("Command = %d, want %d", header.Command, CommandTCP)
	}
	if header.Address != "example.com" {
		t.Errorf("Address = %v, want example.com", header.Address)
	}
	if header.Port != 443 {
		t.Errorf("Port = %d, want 443", header.Port)
	}
}
