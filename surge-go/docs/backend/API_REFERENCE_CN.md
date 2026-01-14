# Surge Go 后端 API 参考文档

后端服务暴露了一个 RESTful API 接口，用于全量的配置管理、状态监控及核心功能控制。

**Base URL**: `http://127.0.0.1:9090` (默认)

## 1. 监控与状态 (Monitoring)

### 获取实时流量统计
`GET /api/stats`

返回当前的上传/下载速度及总量。
**Response:**
```json
{
  "upload_speed": 1024,      // bytes/s
  "download_speed": 20480,   // bytes/s
  "upload_total": 1048576,   // bytes
  "download_total": 5242880, // bytes
  "connections_count": 5
}
```

### 获取代理列表及状态
`GET /api/proxies`

返回所有配置的代理节点及其当前的延迟测试结果。
**Response:**
```json
{
  "proxies": {
    "ProxyA": {
      "type": "vmess",
      "latency": 120, // ms, 0 表示未测试或失败
      "history": [...]
    },
    ...
  }
}
```

### 获取活跃连接
`GET /api/connections`

返回当前活跃的 TCP/UDP 连接详情。
**Response:**
```json
[
  {
    "id": "uuid...",
    "metadata": {
      "network": "tcp",
      "source_ip": "127.0.0.1",
      "source_port": "56789",
      "destination_ip": "1.1.1.1",
      "destination_port": "443",
      "host": "cloudflare.com",
      "process": "curl"
    },
    "upload": 100,
    "download": 5000,
    "start_time": 1678900000,
    "chain": ["Proxy"],
    "rule": "DOMAIN-SUFFIX,cloudflare.com"
  }
]
```

### WebSocket 实时推送
`GET /ws`
建立 WebSocket 连接后，服务器每秒推送一次 `stats` 对象（同 `/api/stats`）。

## 2. 核心控制 (Control)

### 切换出站模式
`POST /api/proxy/mode`

**Request:**
```json
{ "mode": "Global" } // 可选: Direct, Global, Rule
```

### 切换策略组节点
`POST /api/config/proxy-groups/{name}/select`

**Request:**
```json
{ "proxy": "Hong Kong Node" }
```

### 开启/关闭系统代理
`POST /api/system-proxy/enable`
`POST /api/system-proxy/disable`

**Enable Request:**
```json
{ "port": 8888 } // 可选，默认 8888
```

### TUN 模式控制
`POST /api/tun/enable`
`POST /api/tun/disable`

### 测试代理延迟
`POST /api/proxy/test` (ICMP/TCP Ping)
`POST /api/proxy/test-live` (HTTP 请求测试)

**Request:**
```json
{
  "name": "ProxyA",
  "url": "http://www.google.com/generate_204" // 可选
}
```

## 3. 配置管理 (Configuration CRUD)

支持对配置文件的细粒度增删改查。修改后需调用 Save 接口（部分接口自动保存）。

### 代理节点管理
- `GET /api/config/proxies`: 获取列表
- `POST /api/config/proxies`: 新增
- `PUT /api/config/proxies/{name}`: 更新
- `DELETE /api/config/proxies/{name}`: 删除

**Proxy Config Model:**
```json
{
  "name": "HK Server",
  "type": "vmess",
  "server": "1.2.3.4",
  "port": 443,
  "username": "uuid...",
  "password": "...",
  "tls": true,
  "net": "ws"
  // ... 其他协议特定字段
}
```

### 规则管理
- `GET /api/config/rules`: 获取规则列表
- `POST /api/config/rules`: 新增规则
- `PUT /api/config/rules/{index}`: 更新指定位置规则
- `POST /api/config/rules/move`: 移动规则顺序

**Rule Config Model:**
```json
{
  "type": "DOMAIN-SUFFIX",
  "value": "google.com",
  "policy": "Proxy",
  "no_resolve": false,
  "comment": "Google Services"
}
```

### 调试工具
**规则匹配测试**
`POST /api/rules/match`
**Request:**
```json
{
  "url": "https://www.youtube.com",
  "source_ip": "192.168.1.10",
  "process": "Chrome"
}
```

**DNS 查询**
`GET /api/dns/query?host=google.com`
