# Surge-Go HTTP API 文档

## 概述

Surge-Go 提供完整的 HTTP API 用于监控和控制代理服务器。默认监听地址为 `127.0.0.1:9090`，可通过配置文件中的 `http-api` 选项修改。

基础 URL: `http://127.0.0.1:9090`

## 认证

当前版本暂未实现认证机制 (规划中)。建议仅监听本地回环地址。

## API 端点

### 1. 代理管理

#### GET `/api/proxies`

获取所有策略组及其当前选择的代理。

**响应示例**:
```json
{
  "proxies": [
    {
      "name": "Proxy",
      "type": "select",
      "now": "ProxyA"
    },
    {
      "name": "Auto",
      "type": "url-test",
      "now": "ProxyB"
    }
  ]
}
```

#### POST `/api/proxies/{groupName}`

切换指定策略组的当前代理 (仅适用于 `select` 类型)。

**路径参数**:
- `groupName`: 策略组名称 (如 `Proxy`)

**请求体**:
```json
{
  "name": "ProxyA"
}
```

**响应**:
```json
{
  "success": true
}
```

#### GET `/api/proxies/{groupName}/delay`

测试策略组中所有代理的延迟。

**响应示例**:
```json
{
  "ProxyA": 120,
  "ProxyB": 250,
  "Direct": 10
}
```

### 2. 配置管理

#### GET `/api/config/general`

获取通用配置。

**响应示例**:
```json
{
  "loglevel": "info",
  "dns_server": ["8.8.8.8", "1.1.1.1"],
  "encrypted_dns_server": ["https://dns.google/dns-query"],
  "http_api": "127.0.0.1:9090",
  "ipv6": false
}
```

#### GET `/api/config/proxy-groups`

获取所有策略组配置。

**响应示例**:
```json
[
  {
    "name": "Proxy",
    "type": "select",
    "proxies": ["ProxyA", "ProxyB", "Direct"]
  },
  {
    "name": "Auto",
    "type": "url-test",
    "proxies": ["ProxyA", "ProxyB"],
    "url": "http://www.gstatic.com/generate_204",
    "interval": 600
  }
]
```

#### POST `/api/config/reload`

重新加载配置文件 (不中断现有连接)。

**响应**:
```json
{
  "success": true,
  "message": "Config reloaded"
}
```

### 3. 规则测试

#### POST `/api/rules/match`

测试特定请求会匹配到哪条规则和策略。

**请求体**:
```json
{
  "url": "https://www.google.com",
  "source_ip": "192.168.1.100",
  "process": "chrome"
}
```

**响应**:
```json
{
  "adapter": "Proxy",
  "rule": "DOMAIN-SUFFIX,google.com,Proxy"
}
```

### 4. DNS 查询

#### GET `/api/dns/query?host={hostname}`

查询指定域名的 IP 地址 (经过 Host 映射和缓存)。

**查询参数**:
- `host`: 域名 (如 `google.com`)

**响应示例**:
```json
{
  "host": "google.com",
  "ips": ["142.250.185.46", "2404:6800:4004:825::200e"]
}
```

### 5. 统计信息

#### GET `/api/stats/traffic`

获取流量统计 (上传/下载字节数)。

**响应示例**:
```json
{
  "upload": 1048576,
  "download": 5242880
}
```

#### GET `/api/stats/connections`

获取当前活跃连接数。

**响应**:
```json
{
  "count": 42
}
```

### 6. 系统集成

#### POST `/api/system/proxy/enable`

启用系统代理 (macOS)。

**请求体**:
```json
{
  "port": 8888
}
```

#### POST `/api/system/proxy/disable`

禁用系统代理。

#### GET `/api/system/proxy/status`

获取系统代理状态。

**响应**:
```json
{
  "enabled": true,
  "port": 8888
}
```

## WebSocket API (规划中)

### `/api/ws/traffic`

实时流量监控 WebSocket。

**消息格式**:
```json
{
  "timestamp": 1673280000,
  "upload_speed": 102400,
  "download_speed": 512000
}
```

## 错误响应

所有错误响应遵循统一格式:

```json
{
  "error": "详细错误信息"
}
```

常见 HTTP 状态码:
- `200 OK`: 成功
- `400 Bad Request`: 请求参数错误
- `404 Not Found`: 资源不存在
- `500 Internal Server Error`: 服务器内部错误
