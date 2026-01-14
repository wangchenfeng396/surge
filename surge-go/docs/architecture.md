# Surge-Go 架构文档

## 系统概览

Surge-Go 采用模块化设计，各模块职责清晰，通过核心引擎 (`Engine`) 协调工作。

```
┌─────────────────────────────────────────────────────┐
│                   入站服务器                          │
│         HTTP Proxy (8888) / SOCKS5 (8889)          │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│                  核心引擎 (Engine)                    │
│  请求分发 │ 规则匹配 │ 策略选择 │ 代理调度            │
└──┬────────┬──────────┬──────────┬──────────────────┘
   │        │          │          │
   │        │          │          │
   ▼        ▼          ▼          ▼
┌──────┐ ┌──────┐ ┌──────────┐ ┌─────────────┐
│ 规则  │ │ DNS  │ │ 策略组    │ │ 协议客户端   │
│ 引擎  │ │ 模块 │ │ 管理器    │ │ VMess/Trojan│
└──────┘ └──────┘ └──────────┘ └─────────────┘
```

## 核心模块

### 1. Engine (核心引擎)

**位置**: `internal/engine`

**职责**:
- 接收来自入站服务器的连接请求
- 调用规则引擎匹配策略
- 根据策略选择具体代理
- 管理所有代理实例和策略组实例

**关键方法**:
- `Start()`: 初始化引擎，加载配置
- `HandleRequest(metadata)`: 处理单个请求，返回 `protocol.Dialer`
- `Reload()`: 热重载配置

### 2. Rule Engine (规则引擎)

**位置**: `internal/rule`

**职责**:
- 解析并存储规则列表
- 根据请求元数据 (域名/IP/进程) 匹配规则
- 返回匹配到的策略名称

**支持规则类型**:
- DOMAIN, DOMAIN-SUFFIX, DOMAIN-KEYWORD
- IP-CIDR, IP-CIDR6, GEOIP
- PROCESS-NAME (仅 macOS)
- RULE-SET (远程规则集)
- AND, OR, NOT (逻辑组合)

**匹配流程**:
```
Request → Rule Engine → Match (按顺序) → 返回 Policy Name → Engine 查找 Policy → 返回 Dialer
```

### 3. Policy Group (策略组)

**位置**: `internal/policy`

**实现类型**:
- **Select**: 手动选择 (通过 API)
- **URL-Test**: 自动测速选择延迟最低
- **Smart**: 基于历史成功率和延迟智能选择

**关键接口**:
```go
type Group interface {
    protocol.Dialer
    Name() string
    Type() string
    Now() string  // 当前使用的代理
}
```

**订阅支持**:
- `Subscription` 组件定期拉取订阅链接
- 支持 Base64 (Std/URL/Raw) 编码
- 解析 `vmess://` URI 格式
- 自动更新策略组的代理列表

### 4. Protocol Clients (协议客户端)

**位置**: `internal/protocol/{vmess,trojan,vless}`

**实现协议**:
- **VMess**: AEAD 加密 + WebSocket/TCP + TLS
- **Trojan**: SHA256 密码验证 + TLS
- **VLESS**: UUID 验证 + TCP/WebSocket + TLS

**统一接口**:
```go
type Dialer interface {
    DialContext(ctx, network, address) (net.Conn, error)
    Name() string
}
```

### 5. DNS Module (DNS 模块)

**位置**: `internal/dns`

**功能**:
- 静态 Host 映射 (优先级最高)
- 并发查询多个 DNS 服务器
- DoH (DNS over HTTPS) 支持
- LRU 缓存 (基于 TTL)

**解析流程**:
```
查询 → 检查 Host 映射 → 检查缓存 → DoH/UDP 查询 → 缓存结果 → 返回
```

### 6. Server (入站服务器)

**位置**: `internal/server`

**实现**:
- **HTTP**: 处理 CONNECT 请求
- **SOCKS5**: 完整 SOCKS5 协议实现

**集成功能**:
- URL Rewrite (HTTP 专用)
- Body Rewrite (HTTP 专用)
- MITM (HTTPS 解密)

## 数据流向

### 完整请求流程

```
1. 客户端连接 → HTTP/SOCKS5 服务器
2. 服务器解析目标地址 (host:port)
3. 调用 Engine.HandleRequest(metadata)
   ├─ metadata 包含: host, destIP, port, protocol, process
4. Engine 调用 RuleEngine.Match(metadata)
   ├─ 返回 policyName (如 "Proxy")
5. Engine 查找 Policy/Group (e.g., Proxy 策略组)
6. 策略组返回具体 Dialer (如 VMess 客户端)
7. Dialer.DialContext() 建立到远程的连接
8. 服务器进行双向数据转发
```

### MITM 流程

```
1. 客户端发起 HTTPS CONNECT → MITM 服务器
2. MITM 动态签发证书伪装成目标站点
3. 与客户端建立 TLS (使用伪造证书)
4. 与真实服务器建立 TLS (正常验证)
5. 双向解密转发 (可在此进行 Body Rewrite)
```

## 配置管理

**位置**: `internal/config`

**结构**:
- `SurgeConfig`: 顶层配置对象
  - `General`: 通用配置
  - `Proxies`: 代理列表
  - `ProxyGroups`: 策略组列表
  - `Rules`: 规则列表
  - `Hosts`: DNS Host 映射
  - `URLRewrites`, `BodyRewrites`: 重写规则
  - `MITM`: MITM 配置

**解析流程**:
```
配置文件 → ParseSections() → 各 Section 解析器 → 构建 SurgeConfig 对象 → Engine 加载
```

## 性能优化

- **DNS 缓存**: 减少重复查询
- **策略组测速**: 并发测试，避免阻塞
- **连接复用**: 协议客户端支持连接池 (规划中)
- **规则匹配**: 优先匹配常用规则
