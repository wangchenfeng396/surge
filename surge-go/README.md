# Surge-Go

Surge-Go 是一个基于 Go 语言实现的高性能代理服务器，旨在兼容 Surge 配置文件格式，提供强大的规则分流、策略组管理及中间人攻击 (MITM) 功能。

它不依赖任何外部核心库（如 sing-box 或 v2ray-core），而是完全自主实现了核心代理引擎、规则匹配引擎和策略组逻辑。

## 功能特性

- **多协议支持**: 
  - [x] VMess (WebSocket + TLS + AEAD)
  - [x] Trojan (TLS)
  - [x] VLESS (TCP/WebSocket + TLS)
  - [x] HTTP / SOCKS5 入站代理
- **强大的规则引擎**:
  - [x] DOMAIN, DOMAIN-SUFFIX, DOMAIN-KEYWORD
  - [x] IP-CIDR, IP-CIDR6
  - [x] GEOIP
  - [x] PROCESS-NAME (macOS)
  - [x] RULE-SET (远程规则集自动更新)
  - [x] 逻辑规则 (AND, OR, NOT)
- **策略组管理**:
  - [x] Select (手动选择)
  - [x] URL-Test (自动延迟测试)
  - [x] Smart (基于历史稳定性和延迟的智能选择)
  - [x] 代理组嵌套
  - [x] 订阅链接支持 (Surge 格式, vmess:// URI, Base64/Raw)
- **DNS 处理**:
  - [x] 并发 DNS 查询
  - [x] DoH (DNS over HTTPS)
  - [x] 静态 Host 映射
  - [x] DNS 缓存
- **高级功能**:
  - [x] URL Rewrite (正则重写 / 302 重定向)
  - [x] Body Rewrite (HTTP 响应体修改)
  - [x] MITM (HTTPS 解密与证书签发)
  - [x] Script (基础脚本支持预留)

## 快速开始

### 1. 编译构建

需要 Go 1.21+ 环境。

```bash
git clone https://github.com/your-repo/surge-go.git
cd surge-go
go build -o surge cmd/surge/main.go
```

### 2. 准备配置

创建 `surge.conf` 文件（兼容 Surge 格式）：

```ini
[General]
loglevel = info
dns-server = 8.8.8.8, 1.1.1.1
http-listen = 0.0.0.0:8888
socks5-listen = 0.0.0.0:8889
http-api = 127.0.0.1:9090

[Proxy]
Direct = direct
ProxyA = vmess, 1.2.3.4, 10086, username=uuid, tls=true

[Proxy Group]
Proxy = select, ProxyA, Direct
Auto = url-test, ProxyA, Direct, url=http://www.gstatic.com/generate_204, interval=600

[Rule]
DOMAIN-SUFFIX, google.com, Proxy
GEOIP, CN, Direct
FINAL, Proxy
```

### 3. 运行

```bash
./surge -c surge.conf
```

### 4. 控制与监控

HTTP API 默认监听在 `9090` 端口。

- **查看所有代理**: `curl http://127.0.0.1:9090/api/proxies`
- **切换代理**: 
  ```bash
  curl -X POST http://127.0.0.1:9090/api/proxies/Proxy -d '{"name": "ProxyA"}'
  ```

## 目录结构

- `cmd/surge`: 程序入口
- `internal/engine`: 核心代理引擎
- `internal/protocol`: 协议客户端实现 (VMess, Trojan, VLESS)
- `internal/rule`: 规则匹配引擎
- `internal/policy`: 策略组逻辑
- `internal/dns`: DNS 解析与缓存
- `internal/server`: 入站服务器 (HTTP, SOCKS5)
- `internal/mitm`: MITM 中间人攻击实现

## 许可证

MIT License
