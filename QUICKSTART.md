# SurgeProxy Quick Start Guide

## Prerequisites
- macOS 12.0+
- Xcode installed
- Go backend already built

## Starting the Application

### Method 1: Automatic (Recommended)
1. Open `SurgeProxy.app` in Xcode
2. Press ⌘R to build and run
3. The app will automatically start the Go backend

### Method 2: Manual
1. Start Go backend:
   ```bash
   cd surge-go
   ./surge
   ```

2. Launch macOS app from Xcode

## Basic Usage

### Enable System Proxy
1. Open SurgeProxy app
2. Navigate to **Overview** tab
3. Toggle **System Proxy** ON
4. ✅ Your system is now using the proxy

### Monitor Traffic
1. Navigate to **Activity** tab
2. View real-time statistics:
   - Upload/Download speed
   - Active connections
   - Latency information
   - Traffic graphs

### Configure Rules
1. Navigate to **Rule** tab
2. Click **+** to add new rule
3. Configure:
   - Type (Domain, IP, Process, etc.)
   - Value (domain name, IP address, etc.)
   - Policy (DIRECT, REJECT, or proxy name)
4. Click **Save**

### Test Proxy
1. Navigate to **Policy** tab
2. Click **Test All** to test all proxies
3. View latency results

## Verification

### Check if Proxy is Working
```bash
# Test HTTP proxy
curl -x http://127.0.0.1:8888 http://example.com

# Check system proxy settings
scutil --proxy
```

### View API Status
```bash
# Check backend health
curl http://localhost:9090/api/stats

# View processes
curl http://localhost:9090/api/processes

# View devices
curl http://localhost:9090/api/devices
```

## Troubleshooting

### Backend Not Starting
**Problem**: Go backend doesn't start automatically

**Solution**:
1. Check if binary exists: `ls -la surge-go/surge`
2. Make it executable: `chmod +x surge-go/surge`
3. Start manually: `cd surge-go && ./surge`

### No Traffic Statistics
**Problem**: Activity view shows no data

**Solution**:
1. Verify backend is running: `ps aux | grep surge`
2. Check API: `curl http://localhost:9090/api/stats`
3. Restart the app

### System Proxy Not Working
**Problem**: Websites don't go through proxy

**Solution**:
1. Check System Preferences → Network → Advanced → Proxies
2. Verify HTTP/HTTPS proxy is set to 127.0.0.1:8888
3. Try disabling and re-enabling in Overview

### Port Already in Use
**Problem**: Error "address already in use"

**Solution**:
```bash
# Find process using port 9090
lsof -i :9090

# Kill the process
kill -9 <PID>

# Restart backend
cd surge-go && ./surge
```

## Tips

### Performance
- Keep the app running in background for best performance
- Use menu bar icon for quick access
- Monitor Activity view for unusual traffic

### Rules
- Use domain-suffix for wildcard matching
- Test rules with specific websites
- Export rules for backup

### Debugging
- Check Console.app for detailed logs
- Enable verbose logging in Settings
- Use Capture view to inspect traffic

## Keyboard Shortcuts

- `⌘R` - Build and run (Xcode)
- `⌘B` - Build only (Xcode)
- `⌘Q` - Quit application

## Next Steps

1. ✅ Configure your proxy servers in Policy view
2. ✅ Set up rules for different domains
3. ✅ Enable HTTPS decryption if needed
4. ✅ Monitor traffic in Activity view
5. ✅ Customize settings to your preference

## Support

For issues or questions:
1. Check the logs in Console.app
2. Review the README.md
3. Check the integration documentation

---

**Happy Proxying! 🚀**
