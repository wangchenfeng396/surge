# SurgeProxy - Native macOS Application

A beautiful native macOS application with SwiftUI interface to control and monitor the Surge HTTP/HTTPS proxy server.

## Features

- 🎛️ **Visual Server Control** - Start/stop proxy with a single click
- ⚙️ **Configuration Management** - Easy-to-use settings panel
- 🚫 **Domain Filtering** - Block unwanted domains or set direct connections
- 📊 **Real-time Logging** - Monitor all proxy requests in real-time
- 🔧 **Menu Bar Integration** - Quick access from the macOS menu bar
- 🌐 **System Proxy Auto-Config** - Automatically configure macOS system proxy

## Screenshots

The app features a modern, native macOS interface with:
- Tab-based navigation
- Real-time status indicators
- Beautiful gradients and animations
- Dark mode support

## Requirements

- macOS 13.0 or later
- Xcode 14.0 or later (for building)
- Python 3 (for running the proxy server)

## Building the App

### Option 1: Open in Xcode

1. Open `SurgeProxy.xcodeproj` in Xcode
2. Select the "SurgeProxy" scheme
3. Click the "Run" button (⌘R) or Product → Run

### Option 2: Build from Command Line

```bash
# Navigate to the project directory
cd /Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/SurgeProxy

# Build the project (requires Xcode, not just Command Line Tools)
xcodebuild -project SurgeProxy.xcodeproj -scheme SurgeProxy -configuration Release build

# The built app will be in:
# build/Release/SurgeProxy.app
```

## Running the App

1. **Launch the Application**
   - Double-click `SurgeProxy.app` or run from Xcode
   
2. **Start the Proxy Server**
   - Click the "Start Proxy" button in the Control tab
   - The status indicator will turn green when running
   
3. **Configure Settings** (Optional)
   - Go to the Configuration tab
   - Adjust port, host, buffer size, and timeout
   - Click "Save & Apply"
   
4. **Manage Domain Filters** (Optional)
   - Go to the Domains tab
   - Add domains to block or allow direct connections
   
5. **View Logs**
   - Go to the Logs tab
   - See real-time proxy requests
   - Filter by log level or search

## System Proxy Integration

The app can automatically configure your macOS system proxy:

1. Start the proxy server
2. Toggle "Set as System Proxy" in the Control tab
3. All system traffic will now route through the proxy
4. Toggle off to restore original settings

## Architecture

```
┌─────────────────────────────────────┐
│     SwiftUI User Interface          │
│  (ContentView, ServerControlView,   │
│   ConfigurationView, etc.)          │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│       ProxyManager (Swift)          │
│  - Process management               │
│  - Log parsing                      │
│  - System proxy configuration       │
└─────────────┬───────────────────────┘
              │
┌─────────────▼───────────────────────┐
│   Python Proxy Server Process       │
│   (proxy_server.py)                 │
│  - HTTP/HTTPS proxy                 │
│  - Domain filtering                 │
│  - Request forwarding               │
└─────────────────────────────────────┘
```

## Project Structure

```
SurgeProxy/
├── SurgeProxy.xcodeproj/          # Xcode project
├── SurgeProxy/
│   ├── SurgeProxyApp.swift        # App entry point
│   ├── ContentView.swift          # Main UI
│   ├── Models/
│   │   ├── ProxyConfig.swift      # Configuration model
│   │   └── ProxyManager.swift     # Proxy controller
│   ├── Views/
│   │   ├── ServerControlView.swift
│   │   ├── ConfigurationView.swift
│   │   ├── DomainFilterView.swift
│   │   └── LogView.swift
│   ├── Resources/
│   │   ├── proxy_server.py        # Python proxy server
│   │   └── config.json            # Default config
│   └── Assets.xcassets/
└── README.md
```

## Configuration

The app uses a JSON configuration file that matches the Python proxy server format:

```json
{
  "port": 8888,
  "host": "127.0.0.1",
  "buffer_size": 8192,
  "timeout": 30,
  "blocked_domains": ["ads.example.com"],
  "direct_domains": ["localhost"],
  "rules": []
}
```

Configuration is automatically saved to UserDefaults and persists between app launches.

## Troubleshooting

### Proxy won't start
- Ensure Python 3 is installed: `python3 --version`
- Check if port 8888 is already in use
- View logs in the Logs tab for error messages

### System proxy not working
- Ensure the proxy server is running first
- Check System Preferences → Network → Advanced → Proxies
- Try toggling the system proxy off and on again

### Build errors in Xcode
- Ensure you have Xcode installed (not just Command Line Tools)
- Clean build folder: Product → Clean Build Folder
- Restart Xcode

## Development

The app is built with:
- **Language**: Swift 5.0
- **Framework**: SwiftUI
- **Minimum macOS**: 13.0
- **Architecture**: Native macOS app with Python subprocess

## License

MIT License - Free to use, modify, and distribute

## Credits

Built on top of the Surge-inspired Python proxy server implementation.
