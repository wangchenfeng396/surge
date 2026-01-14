# Usage Guide - Surge Proxy Server

## Installation

No installation required! This proxy server uses only Python standard library.

### Prerequisites
- Python 3.6 or higher

### Setup
```bash
git clone <repository-url>
cd surge
```

## Running the Server

### Method 1: Using Python directly
```bash
python3 proxy_server.py
```

### Method 2: Using the start script
```bash
./start.sh
```

The server will start on `0.0.0.0:8888` by default.

## Configuration

Edit `config.json` to customize the proxy behavior:

### Basic Settings
```json
{
  "port": 8888,          // Listening port
  "host": "0.0.0.0",     // Listening address
  "buffer_size": 8192,   // Buffer size in bytes
  "timeout": 30          // Connection timeout in seconds
}
```

### Domain Blocking
Block unwanted domains by adding them to the `blocked_domains` list:
```json
{
  "blocked_domains": [
    "ads.example.com",
    "tracker.example.com",
    "malware.site.com"
  ]
}
```

### Direct Connections
Specify domains that should bypass the proxy:
```json
{
  "direct_domains": [
    "localhost",
    "127.0.0.1",
    "internal.company.com"
  ]
}
```

### Proxy Rules
Define custom routing rules:
```json
{
  "rules": [
    {
      "type": "DOMAIN-SUFFIX",
      "pattern": ".cn",
      "action": "DIRECT",
      "description": "Chinese domains go direct"
    },
    {
      "type": "DOMAIN-KEYWORD",
      "pattern": "google",
      "action": "PROXY",
      "description": "Google services through proxy"
    }
  ]
}
```

## Testing

### Run the test suite
```bash
python3 test_proxy.py
```

### Manual testing with curl

Test HTTP:
```bash
curl -v -x http://127.0.0.1:8888 http://example.com
```

Test HTTPS:
```bash
curl -v -x http://127.0.0.1:8888 https://example.com
```

## Browser Configuration

### Chrome / Chromium
1. Settings → Advanced → System → Open proxy settings
2. Set HTTP Proxy: `127.0.0.1:8888`
3. Set HTTPS Proxy: `127.0.0.1:8888`

### Firefox
1. Preferences → General → Network Settings
2. Manual proxy configuration
3. HTTP Proxy: `127.0.0.1` Port: `8888`
4. Check "Also use this proxy for HTTPS"

### Safari (macOS)
1. Preferences → Advanced → Proxies
2. Configure Proxies: `127.0.0.1:8888`

## Environment Variables

Set system-wide proxy (Linux/macOS):
```bash
export http_proxy=http://127.0.0.1:8888
export https_proxy=http://127.0.0.1:8888
```

## Troubleshooting

### Port already in use
Change the port in `config.json`:
```json
{
  "port": 9999
}
```

### Connection timeout
Increase timeout in `config.json`:
```json
{
  "timeout": 60
}
```

### Debug mode
Check server logs for detailed information about requests and errors.

### Permission denied (port < 1024)
Use sudo or choose a port > 1024:
```bash
sudo python3 proxy_server.py
```

## Advanced Usage

### Running as a background service

Using nohup:
```bash
nohup python3 proxy_server.py > proxy.log 2>&1 &
```

Using systemd (Linux):
Create `/etc/systemd/system/surge-proxy.service`:
```ini
[Unit]
Description=Surge Proxy Server
After=network.target

[Service]
Type=simple
User=your-username
WorkingDirectory=/path/to/surge
ExecStart=/usr/bin/python3 /path/to/surge/proxy_server.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable surge-proxy
sudo systemctl start surge-proxy
```

## Security Considerations

1. **Local Use Only**: By default, binds to `0.0.0.0`. For local-only access, change to `127.0.0.1`
2. **No Authentication**: This implementation has no authentication. Do not expose to public networks.
3. **HTTPS Inspection**: Does not inspect HTTPS content (only forwards encrypted traffic)
4. **Trusted Networks**: Only use in trusted network environments

## Performance Tips

1. Adjust `buffer_size` based on your network:
   - Low latency: 4096
   - Balanced: 8192 (default)
   - High throughput: 16384

2. Adjust `timeout` based on your needs:
   - Fast networks: 10-15 seconds
   - Slow networks: 30-60 seconds

3. For high concurrent connections, consider increasing system limits:
   ```bash
   ulimit -n 4096
   ```
