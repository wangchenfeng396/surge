# SurgeProxy

A high-performance macOS proxy application with a Surge-like interface, built with SwiftUI frontend and Go backend.

## Features

### Core Proxy Functionality
- ✅ HTTP/HTTPS proxy (port 8888)
- ✅ SOCKS5 proxy (port 1080)
- ✅ System proxy integration
- ✅ Rule-based routing
- ✅ Policy groups
- ✅ Real-time traffic monitoring

### Advanced Features
- ✅ HTTPS decryption (MITM)
- ✅ Request/Response capture
- ✅ URL rewriting and mapping
- ✅ Process tracking
- ✅ Device management
- ✅ GeoIP-based routing
- ✅ Composite rules (AND/OR/NOT)
- ✅ Ruleset support

### UI Features
- ✅ Activity dashboard with real-time stats
- ✅ Overview with feature toggles
- ✅ Process and device monitoring
- ✅ Policy management
- ✅ Rule editor with import/export
- ✅ Settings and configuration

## Architecture

```
┌─────────────────────────────────────┐
│      SwiftUI Frontend (macOS)       │
│  - Activity View                    │
│  - Overview View                    │
│  - Process/Device Views             │
│  - Policy & Rule Management         │
└──────────────┬──────────────────────┘
               │
               │ REST API + WebSocket
               │ (localhost:9090)
               │
┌──────────────▼──────────────────────┐
│         Go Backend (surge-go)       │
│  - HTTP Proxy (8888)                │
│  - SOCKS5 Proxy (1080)              │
│  - API Server (9090)                │
│  - WebSocket (real-time updates)    │
│  - Rule Engine                      │
│  - Traffic Statistics               │
└─────────────────────────────────────┘
```

## Installation

### Prerequisites
- macOS 12.0+
- Xcode 14.0+
- Go 1.21+

### Build Go Backend

```bash
cd surge-go
go build -o surge cmd/surge/main.go
```

### Build Swift Frontend

```bash
cd SurgeProxy
open SurgeProxy.xcodeproj
# Build and run in Xcode (⌘R)
```

## Usage

### Starting the Application

1. **Start Go Backend** (automatic when using GoProxyManager):
   ```bash
   cd surge-go
   ./surge
   ```

2. **Launch macOS App**:
   - Open SurgeProxy.app
   - Click "System Proxy" toggle in Overview
   - Monitor traffic in Activity view

### Configuration

#### System Proxy
- Toggle in Overview → Network Takeover → System Proxy
- Automatically configures macOS network settings

#### Rules
- Navigate to Rule view
- Add/edit/delete rules
- Import/export Surge format
- Support for domain, IP, process-based rules

#### Policies
- Configure proxy servers in Policy view
- Create policy groups
- Test latency for each proxy

### API Endpoints

The Go backend exposes the following REST API:

- `GET /api/stats` - Current statistics
- `GET /api/processes` - Active processes
- `GET /api/devices` - Connected devices
- `POST /api/test/direct` - Test direct connection
- `POST /api/test/proxy` - Test proxy connection
- `POST /api/config` - Update configuration
- `WS /ws` - WebSocket for real-time updates

## Development

### Project Structure

```
surge/
├── SurgeProxy/              # Swift macOS app
│   ├── Models/              # Data models
│   ├── Views/               # SwiftUI views
│   ├── Services/            # API & WebSocket clients
│   └── Extensions/          # Helper extensions
│
└── surge-go/                # Go backend
    ├── cmd/surge/           # Main entry point
    ├── internal/
    │   ├── proxy/           # Proxy servers
    │   ├── api/             # REST API & WebSocket
    │   ├── policy/          # Rule engine
    │   ├── stats/           # Statistics collector
    │   ├── capture/         # Traffic capture
    │   └── tester/          # Connectivity testing
    └── pkg/                 # Shared packages
```

### Key Components

#### Swift Frontend
- **GoProxyManager**: Manages Go backend process and API communication
- **APIClient**: REST API client for backend
- **WebSocketClient**: Real-time data updates
- **NetworkStats**: Data models for statistics

#### Go Backend
- **Proxy Server**: HTTP/HTTPS/SOCKS5 implementation
- **Rule Engine**: Policy-based routing
- **API Server**: REST endpoints and WebSocket
- **Stats Collector**: Real-time traffic monitoring

## Testing

### Manual Testing
1. Enable System Proxy
2. Browse websites
3. Verify traffic appears in Activity view
4. Check process tracking
5. Test rule-based routing

### API Testing
```bash
# Health check
curl http://localhost:9090/api/stats

# Test direct connection
curl -X POST http://localhost:9090/api/test/direct

# WebSocket test
wscat -c ws://localhost:9090/ws
```

## Troubleshooting

### Go Backend Not Starting
- Check if port 9090 is available
- Verify Go binary exists at `surge-go/surge`
- Check logs in Console.app

### System Proxy Not Working
- Ensure app has network permissions
- Check System Preferences → Network → Advanced → Proxies
- Verify proxy is set to 127.0.0.1:8888

### No Traffic Statistics
- Verify WebSocket connection
- Check Go backend is running
- Restart the application

## License

MIT License - See LICENSE file for details

## Credits

Inspired by [Surge for Mac](https://nssurge.com/)

Built with:
- SwiftUI
- Go
- WebSocket
- REST API
