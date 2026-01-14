# Surge-Go Configuration Guide

This document details the configuration support in `surge-go` based on the analysis of `bin/surge.conf` and the current backend implementation.

## Feature Support Matrix

| Category | Feature | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Proxy Protocols** | **VMess** | ✅ Supported | Full support (WS, TLS, UUID). |
| | **VLESS** | ✅ Supported | Full support. |
| | **Trojan** | ✅ Supported | Full support. |
| | **Snell** | ❌ Unsupported | Config parsed but protocol not implemented. |
| | **Hysteria2** | ❌ Unsupported | Config parsed but protocol not implemented. |
| | **Shadowsocks** | ❌ Unsupported | Config parsed but protocol not implemented. |
| **Proxy Groups** | **Select** | ✅ Supported | Manual selection. |
| | **URL-Test** | ✅ Supported | Auto-selection based on latency. |
| | **Relay** | ✅ Supported | Chain proxies. |
| | **Smart** | ✅ Supported | Smart selection (specific to Surge). |
| **Routing Rules** | **DOMAIN** | ✅ Supported | Including `DOMAIN-SUFFIX`, `DOMAIN-KEYWORD`. |
| | **IP-CIDR** | ✅ Supported | IPv4 and IPv6 CIDR matching. |
| | **PROCESS-NAME** | ✅ Supported | Matches process name or full path. |
| | **GEOIP** | ✅ Supported | Requires MMDB database. |
| | **RULE-SET** | ✅ Supported | Supports remote rule sets. |
| | **AND** | ✅ Supported | Complex logic (e.g., `AND,((PROTOCOL,UDP),...)`). |
| | **FINAL** | ✅ Supported | Fallback rule. |
| **Rewrites** | **URL Rewrite** | ✅ Supported | Full support for 302, reject, and header modification. |
| | **Body Rewrite** | ✅ Supported | Full support for `http-request` and `http-response` body replacement. |
| **MITM** | **HTTPS Decryption** | ✅ Supported | Full support with dynamic certificate generation and interception. |
| **General** | **TUN Mode** | ⚠️ WIP | Code implemented. Run `scripts/fix_tun_mode.sh` to fix dependencies and enable. |
| | **DNS** | ✅ Supported | Custom DNS servers and local host mapping. |

## Configuration Reference

### 1. General Section
Core settings for the backend engine.
```ini
[General]
loglevel = notify
dns-server = 223.5.5.5, 114.114.114.114
http-api = 127.0.0.1:19090
test-timeout = 10
```

### 2. Proxy Definitions
Define individual proxy servers. Only the supported types below will function correctly.

**VMess Example:**
```ini
[Proxy]
MyVMess = vmess, server.com, 443, username=uuid-here, ws=true, tls=true
```

**Trojan Example:**
```ini
[Proxy]
MyTrojan = trojan, server.com, 443, password=pass, sni=server.com
```

### 3. Proxy Groups
Group proxies for policy selection.

```ini
[Proxy Group]
# Auto Select (Best Ping)
Auto = url-test, Proxy1, Proxy2, url=http://www.gstatic.com/generate_204

# Manual Select
Manual = select, Proxy1, Proxy2, DIRECT
```

### 4. Routing Rules
Rules determine how traffic is routed. They are matched from top to bottom.

```ini
[Rule]
# Process Rules (Highest Priority usually)
PROCESS-NAME,/Applications/Chrome.app/Contents/MacOS/Google Chrome,Proxy

# Domain Rules
DOMAIN,google.com,Proxy
DOMAIN-SUFFIX,google.com,Proxy

# IP Rules
IP-CIDR,10.0.0.0/8,DIRECT,no-resolve

# Logical Rules
AND,((PROTOCOL,UDP), (DEST-PORT,443)),REJECT

# Final Fallback
FINAL,Proxy,dns-failed
```

## Setup & Verification
To verify your configuration is compatible:

1.  Place your config at `bin/surge.conf`.
2.  Run the config verification suite:
    ```bash
    go test -v ./cmd/config_verification
    ```
3.  Check the output for routing matches and connectivity results.
