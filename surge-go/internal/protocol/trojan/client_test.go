package trojan

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
				Password: "mypassword",
			},
			wantErr: false,
		},
		{
			name: "empty server",
			config: &Config{
				Port:     443,
				Password: "mypassword",
			},
			wantErr: true,
		},
		{
			name: "invalid port",
			config: &Config{
				Server:   "example.com",
				Port:     99999,
				Password: "mypassword",
			},
			wantErr: true,
		},
		{
			name: "empty password",
			config: &Config{
				Server: "example.com",
				Port:   443,
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
			name: "basic trojan config",
			config: &protocol.ProxyConfig{
				Name:   "test-trojan",
				Type:   "trojan",
				Server: "example.com",
				Port:   443,
				Options: map[string]interface{}{
					"password": "mypassword",
				},
			},
			want: &Config{
				Name:     "test-trojan",
				Server:   "example.com",
				Port:     443,
				Password: "mypassword",
			},
			wantErr: false,
		},
		{
			name: "trojan with sni",
			config: &protocol.ProxyConfig{
				Name:   "test-trojan-sni",
				Type:   "trojan",
				Server: "example.com",
				Port:   443,
				Options: map[string]interface{}{
					"password":         "mypassword",
					"sni":              "example.org",
					"skip-cert-verify": true,
				},
			},
			want: &Config{
				Name:          "test-trojan-sni",
				Server:        "example.com",
				Port:          443,
				Password:      "mypassword",
				SNI:           "example.org",
				AllowInsecure: true,
			},
			wantErr: false,
		},
		{
			name: "trojan with username field",
			config: &protocol.ProxyConfig{
				Name:   "test-trojan-username",
				Type:   "trojan",
				Server: "example.com",
				Port:   443,
				Options: map[string]interface{}{
					"username": "JP-Oracle-AI",
				},
			},
			want: &Config{
				Name:     "test-trojan-username",
				Server:   "example.com",
				Port:     443,
				Password: "JP-Oracle-AI",
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
			if got.Password != tt.want.Password {
				t.Errorf("Password = %v, want %v", got.Password, tt.want.Password)
			}
		})
	}
}

func TestGeneratePasswordHash(t *testing.T) {
	tests := []struct {
		password string
		want     string
	}{
		{
			password: "password",
			want:     "d63dc919e201d7bc4c825630d2cf25fdc93d4b2f0d46706d29038d01",
		},
		{
			password: "mypassword",
			want:     "9b1cdbab8c8410d63ca8700b12d03b9f0bf93d33b793653cc0983ef3",
		},
	}

	for _, tt := range tests {
		t.Run(tt.password, func(t *testing.T) {
			got := GeneratePasswordHash(tt.password)
			if got != tt.want {
				t.Errorf("GeneratePasswordHash() = %v, want %v", got, tt.want)
			}
		})
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
			name: "without SNI",
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
		Name:     "test",
		Server:   "example.com",
		Port:     443,
		Password: "mypassword",
	}

	client, err := NewClient(config)
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}

	if client.Name() != "test" {
		t.Errorf("Name() = %v, want test", client.Name())
	}

	if client.Type() != "trojan" {
		t.Errorf("Type() = %v, want trojan", client.Type())
	}

	// Check password hash is generated
	expectedHash := GeneratePasswordHash("mypassword")
	if client.passwordHash != expectedHash {
		t.Errorf("passwordHash = %v, want %v", client.passwordHash, expectedHash)
	}
}

func TestNewClientFromProxyConfig(t *testing.T) {
	cfg := &protocol.ProxyConfig{
		Name:   "test-trojan",
		Type:   "trojan",
		Server: "jp.2233.cloud",
		Port:   443,
		Options: map[string]interface{}{
			"username":         "JP-Oracle-AI",
			"password":         "f8a90150d4c1cb181825c296734b1520",
			"sni":              "jp.2233.cloud",
			"skip-cert-verify": true,
			"tfo":              true,
		},
	}

	client, err := NewClientFromProxyConfig(cfg)
	if err != nil {
		t.Fatalf("NewClientFromProxyConfig() error = %v", err)
	}

	if client.Name() != "test-trojan" {
		t.Errorf("Name() = %v, want test-trojan", client.Name())
	}

	if client.Type() != "trojan" {
		t.Errorf("Type() = %v, want trojan", client.Type())
	}

	// Password should be from username field (password field takes precedence if both exist)
	expectedHash := GeneratePasswordHash("f8a90150d4c1cb181825c296734b1520")
	if client.passwordHash != expectedHash {
		t.Errorf("passwordHash mismatch")
	}
}
