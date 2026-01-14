# 数据模型定义 (Data Models)

本文档定义了 Surge Go 后端 API 中使用的核心数据结构。

## 1. ProxyObject (代理节点)

表示一个代理服务器配置。

```json
{
    "name": "string (Unique ID)",
    "type": "string (ss, vmess, vless, trojan, socks5, http, direct, reject)",
    "server": "string (Host/IP)",
    "port": "int",
    
    // Auth
    "username": "string (UUID for VMess, User for Socks/HTTP)",
    "password": "string",
    "password_payload": "string (0-rtt for SS)",

    // Transport / Stream Settings
    "tls": "bool",
    "skip_cert_verify": "bool",
    "sni": "string",
    "network": "string (tcp, ws, grpc, h2)",
    "ws_path": "string",
    "ws_headers": "{key: value}",
    "grpc_service_name": "string",

    // VMess Specific
    "alter_id": "int",
    "cipher": "string (auto, aes-128-gcm...)",

    // Shadowsocks Specific
    "encrypt_method": "string (aes-256-gcm...)",
    "plugin": "string (obfs, v2ray-plugin)",
    "plugin_opts": "string"
}
```

## 2. RuleObject (路由规则)

表示一条分流规则。

```json
{
    "type": "string",
    // Type Enum: 
    // DOMAIN, DOMAIN-SUFFIX, DOMAIN-KEYWORD, 
    // IP-CIDR, IP-CIDR6, GEOIP, 
    // PROCESS-NAME, PROCESS-PATH, 
    // URL-REGEX, 
    // FINAL
    
    "value": "string (Payload, e.g. google.com)",
    "policy": "string (Adapter Name or Policy Group Name)",
    "no_resolve": "bool (Option for IP rules)",
    "comment": "string"
}
```

## 3. ProxyGroupObject (策略组)

表示一个代理集合或自动选择组。

```json
{
    "name": "string",
    "type": "string (select, url-test, fallback, load-balance)",
    "proxies": ["string (Proxy Names)"],
    "url": "string (Test URL)",
    "interval": "int (Seconds)",
    "tolerance": "int (ms)",
    "selected": "string (Current Active Proxy, for select type)"
}
```

## 4. StatsObject (统计信息)

```json
{
    "upload_speed": "int64 (bytes/s)",
    "download_speed": "int64 (bytes/s)",
    "upload_total": "int64 (Total bytes)",
    "download_total": "int64 (Total bytes)",
    "connections_count": "int (Active connections)",
    "start_time": "int64 (Unix Timestamp)"
}
```

## 5. ConnectionObject (连接详情)

```json
{
    "id": "string (UUID)",
    "metadata": {
        "network": "string (tcp/udp)",
        "type": "string (HTTP/HTTPS/SOCKS)",
        "source_ip": "string",
        "source_port": "string",
        "destination_ip": "string",
        "destination_port": "string",
        "host": "string (Target Hostname)",
        "process": "string (Process Name)",
        "process_path": "string (Full Path)"
    },
    "upload": "int64",
    "download": "int64",
    "start_time": "int64",
    "rule": "string (Matched Rule)",
    "chain": ["string (Proxy Chain)"]
}
```
