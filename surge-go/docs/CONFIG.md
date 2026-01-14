# Surge 配置文件说明

## surge.conf 格式

Surge 配置文件采用 INI 格式，由多个 section 组成。

---

## 配置 Section

### [General]

通用配置选项。

```ini
[General]
# 日志级别: verbose, info, notify, warning
loglevel = notify

# DNS 服务器
dns-server = 223.5.5.5, 114.114.114.114, system

# 加密 DNS 服务器
encrypted-dns-server = https://dns.alidns.com/dns-query

# 测试超时时间（秒）
test-timeout = 5

# IPv6 支持
ipv6 = false

# 跳过代理
skip-proxy = 127.0.0.1, 192.168.0.0/16, 10.0.0.0/8, localhost, *.local

# 允许 Wi-Fi 访问
allow-wifi-access = true
wifi-access-http-port = 6152
wifi-access-socks5-port = 6153

# HTTP API
http-api-web-dashboard = true
http-api-tls = false

# 其他选项
exclude-simple-hostnames = true
show-error-page-for-reject = true
```

**常用选项**

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `loglevel` | 日志级别 | `notify` |
| `dns-server` | DNS 服务器列表 | 系统 DNS |
| `encrypted-dns-server` | DoH/DoT 服务器 | 无 |
| `ipv6` | 启用 IPv6 | `false` |
| `test-timeout` | 延迟测试超时 | `5` |
| `skip-proxy` | 跳过代理的地址 | 本地地址 |

---

### [Proxy]

代理服务器定义。

#### VMess

```ini
Proxy-Name = vmess, server.com, 443, username=UUID, ws=true, ws-path=/path, tls=true, sni=server.com
```

**参数**
- `username`: UUID
- `ws`: 是否启用 WebSocket (`true`/`false`)
- `ws-path`: WebSocket 路径
- `tls`: 是否启用 TLS
- `sni`: SNI 服务器名
- `skip-cert-verify`: 跳过证书验证
- `alterId`: Alter ID（默认 0）

#### VLESS

```ini
Proxy-Name = vless, server.com, 443, username=UUID, tls=true, sni=server.com
Proxy-XTLS = vless, server.com, 443, username=UUID, flow=xtls-rprx-vision, tls=true
```

**参数**
- `username`: UUID
- `flow`: XTLS flow (如 `xtls-rprx-vision`)
- `ws`: WebSocket 传输
- `ws-path`: WebSocket 路径
- `grpc`: gRPC 传输
- `grpc-service-name`: gRPC 服务名

#### Trojan

```ini
Proxy-Name = trojan, server.com, 443, password=PASSWORD, sni=server.com
Proxy-WS = trojan, server.com, 443, password=PASSWORD, ws=true, ws-path=/trojan
```

**参数**
- `password`: 密码
- `sni`: SNI 服务器名
- `ws`: WebSocket 模式
- `ws-path`: WebSocket 路径

#### Shadowsocks

```ini
Proxy-Name = ss, server.com, 8388, encrypt-method=aes-256-gcm, password=PASSWORD
```

**参数**
- `encrypt-method`: 加密方式
  - `aes-128-gcm`
  - `aes-256-gcm`
  - `chacha20-ietf-poly1305`
- `password`: 密码
- `udp-relay`: UDP 转发
- `obfs`: 混淆方式
- `obfs-host`: 混淆主机

#### Hysteria2

```ini
Proxy-Name = hysteria2, server.com, 443, password=PASSWORD, up=100, down=500, sni=server.com
```

**参数**
- `password`: 认证密码
- `up`: 上传速度 (Mbps)
- `down`: 下载速度 (Mbps)
- `sni`: SNI 服务器名

---

### [Proxy Group]

代理组定义，用于代理策略选择。

#### Select - 手动选择

```ini
Group-Name = select, Proxy1, Proxy2, Proxy3, DIRECT
```

用户手动选择使用哪个代理。

#### URL-Test - 自动选择

```ini
Group-Name = url-test, Proxy1, Proxy2, url=http://www.gstatic.com/generate_204, interval=600, tolerance=100
```

**参数**
- `url`: 测试 URL
- `interval`: 测试间隔（秒）
- `tolerance`: 容错值（毫秒）

自动选择延迟最低的代理。

#### Fallback - 故障转移

```ini
Group-Name = fallback, Proxy1, Proxy2, Proxy3, url=http://www.gstatic.com/generate_204
```

按顺序测试，使用第一个可用的代理。

#### Load-Balance - 负载均衡

```ini
Group-Name = load-balance, Proxy1, Proxy2, Proxy3
```

在多个代理之间进行负载均衡。

#### Relay - 链式代理

```ini
Group-Name = relay, Proxy1, Proxy2
```

流量依次通过多个代理（链式代理）。

#### SSID - 根据 Wi-Fi 切换

```ini
Group-Name = ssid, default=Proxy1, "Wi-Fi-Name"=Proxy2, cellular=DIRECT
```

根据当前连接的 Wi-Fi 网络自动切换策略。

#### 外部订阅

```ini
Group-Name = select, policy-path=https://example.com/proxies.txt, update-interval=86400
```

**参数**
- `policy-path`: 订阅 URL
- `update-interval`: 更新间隔（秒）
- `policy-regex-filter`: 正则过滤器

---

### [Rule]

路由规则定义。

#### 基本规则

```ini
# 域名完全匹配
DOMAIN,google.com,Proxy

# 域名后缀匹配
DOMAIN-SUFFIX,google.com,Proxy

# 域名关键字匹配
DOMAIN-KEYWORD,google,Proxy

# IP 地址段
IP-CIDR,192.168.0.0/16,DIRECT

# IPv6 地址段
IP-CIDR6,2001:db8::/32,DIRECT

# GeoIP 匹配
GEOIP,CN,DIRECT

# User-Agent 匹配
USER-AGENT,*GoogleBot*,Proxy

# URL 正则匹配
URL-REGEX,^https://www\.google\.com,Proxy

# 进程名匹配
PROCESS-NAME,Telegram,Proxy

# 最终规则
FINAL,Proxy
```

#### 规则选项

```ini
# 不解析域名
DOMAIN-SUFFIX,example.com,Proxy,no-resolve

# 添加注释
DOMAIN,google.com,Proxy // Google services
```

#### 规则集

```ini
# 外部规则集
RULE-SET,https://example.com/rules.txt,Proxy,update-interval=86400
```

#### 逻辑规则

```ini
# AND - 所有条件都满足
AND,((DOMAIN,google.com),(USER-AGENT,*Chrome*)),Proxy

# OR - 任一条件满足
OR,((DOMAIN,google.com),(DOMAIN,youtube.com)),Proxy

# NOT - 条件不满足
NOT,((GEOIP,CN)),Proxy
```

---

### [Host]

本地 DNS 映射。

```ini
[Host]
# IP 映射
example.com = 1.2.3.4

# IPv6 映射
example.com = 2001:db8::1

# 别名
alias.com = example.com

# 指定 DNS 服务器
example.com = server:8.8.8.8
```

---

### [URL Rewrite]

URL 重写规则。

```ini
[URL Rewrite]
# 302 重定向
^http://example\.com http://example.net 302

# 307 重定向
^http://old\.com http://new.com 307

# Header 重写
^http://example\.com header

# 拒绝
^http://ad\.com - reject

# 正则替换
^http://example\.com/(.+) http://new.com/$1 302
```

---

### [Header Rewrite]

HTTP 请求/响应头修改。

```ini
[Header Rewrite]
# 修改请求头
http-request ^http://example\.com header-add X-Custom-Header value
http-request ^http://example\.com header-del User-Agent

# 修改响应头
http-response ^http://example\.com header-replace Content-Type application/json
```

---

### [MITM]

中间人解密配置。

```ini
[MITM]
# 启用 MITM
enable = true

# 跳过服务器证书验证
skip-server-cert-verify = true

# 解密的主机名
hostname = *.google.com, *.apple.com

# 排除的主机名
hostname = -*.example.com

# TCP 连接
tcp-connection = true

# HTTP/2
h2 = true
```

---

## 完整配置示例

```ini
[General]
loglevel = notify
dns-server = 223.5.5.5, 114.114.114.114
ipv6 = false
skip-proxy = 127.0.0.1, 192.168.0.0/16, 10.0.0.0/8, localhost, *.local
allow-wifi-access = true
wifi-access-http-port = 6152

[Proxy]
Direct = direct
Reject = reject

# VMess
VMess-1 = vmess, server1.com, 443, username=uuid-1, ws=true, ws-path=/path, tls=true, sni=server1.com

# VLESS
VLESS-1 = vless, server2.com, 443, username=uuid-2, ws=true, ws-path=/vless, tls=true

# Trojan
Trojan-1 = trojan, server3.com, 443, password=password123

# Shadowsocks
SS-1 = ss, server4.com, 8388, encrypt-method=aes-256-gcm, password=password456

[Proxy Group]
# 手动选择
Proxy = select, Auto, VMess-1, VLESS-1, Trojan-1, SS-1, DIRECT

# 自动选择
Auto = url-test, VMess-1, VLESS-1, Trojan-1, SS-1, url=http://www.gstatic.com/generate_204, interval=600

# 故障转移
Fallback = fallback, VMess-1, VLESS-1, url=http://www.gstatic.com/generate_204

# 链式代理
Chain = relay, VMess-1, Trojan-1

[Rule]
# 广告拦截
DOMAIN-SUFFIX,ad.com,REJECT

# 国内直连
DOMAIN-SUFFIX,cn,DIRECT
GEOIP,CN,DIRECT

# 国外代理
DOMAIN-SUFFIX,google.com,Proxy
DOMAIN-SUFFIX,youtube.com,Proxy
DOMAIN-SUFFIX,facebook.com,Proxy

# 默认规则
FINAL,Proxy

[Host]
localhost = 127.0.0.1

[MITM]
hostname = *.google.com, *.apple.com
skip-server-cert-verify = true
```

---

## 配置文件位置

- macOS: `~/Library/Application Support/Surge/surge.conf`
- 项目默认: `surge-go/surge.conf`

---

## 配置验证

使用命令行验证配置：

```bash
./surge-go -c surge.conf -t
```

---

## 最佳实践

1. **定期备份配置文件**
2. **使用代理组而不是直接引用代理**
3. **正确设置规则顺序**（从特殊到一般）
4. **使用注释说明规则用途**
5. **定期更新外部规则集和订阅**
6. **避免过多的正则规则**（影响性能）
7. **合理设置测试间隔**（避免频繁测试）

---

## 常见问题

### Q: 如何切换代理？
A: 修改 `[Proxy Group]` 中的 select 组，或通过 API 动态切换。

### Q: 规则不生效？
A: 检查规则顺序，确保 `FINAL` 规则在最后。

### Q: MITM 无法解密？
A: 确保安装了 CA 证书，并在 `[MITM]` 中添加了目标域名。

### Q: 如何添加订阅？
A: 在 `[Proxy Group]` 中使用 `policy-path` 参数。

### Q: 配置修改后如何生效？
A: 重新加载配置或重启服务。通过 API 可以动态更新而无需重启。
