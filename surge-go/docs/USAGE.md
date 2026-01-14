# Surge Go 使用指南

## 快速开始

### 安装

#### 从源码编译

```bash
cd surge-go
go build -o bin/surge-go ./cmd/surge
```

#### 二进制文件

编译后的二进制文件位于 `surge-go/bin/surge-go`

---

## 基本使用

### 启动服务

```bash
# 使用默认配置文件
./surge-go

# 指定配置文件
./surge-go -c /path/to/surge.conf

# 测试配置
./surge-go -c surge.conf -t
```

### 命令行参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-c` | 配置文件路径 | `surge.conf` |
| `-t` | 测试配置并退出 | `false` |

---

## 服务端口

启动后，服务将监听以下端口：

- **代理服务**: `http://127.0.0.1:8888` (HTTP/SOCKS5 混合模式)
- **API 服务器**: `http://localhost:9090`
- **WebSocket**: `ws://localhost:9090/ws`

---

## 配置管理

### 通过配置文件

编辑 `surge.conf` 文件，然后重启服务：

```ini
[General]
loglevel = notify
dns-server = 223.5.5.5, 114.114.114.114

[Proxy]
VMess-1 = vmess, server.com, 443, username=uuid
# ... 更多代理

[Proxy Group]
Auto = url-test, VMess-1, VLESS-1

[Rule]
DOMAIN,google.com,Auto
FINAL,DIRECT
```

### 通过 API

无需重启服务，动态修改配置：

```bash
# 添加代理
curl -X POST http://localhost:9090/api/config/proxies \
  -H "Content-Type: application/json" \
  -d '{
    "name": "MyProxy",
    "type": "vmess",
    "server": "example.com",
    "port": 443,
    "username": "your-uuid"
  }'

# 更新配置
curl -X PUT http://localhost:9090/api/config/general \
  -H "Content-Type: application/json" \
  -d '{"loglevel": "info"}'
```

---

## 系统代理设置

### macOS

#### 通过 API

```bash
# 启用系统代理
curl -X POST http://localhost:9090/api/system-proxy/enable \
  -H "Content-Type: application/json" \
  -d '{"port": 8888}'

# 禁用系统代理
curl -X POST http://localhost:9090/api/system-proxy/disable

# 查看状态
curl http://localhost:9090/api/system-proxy/status
```

#### 手动设置

1. 打开 **系统偏好设置** → **网络**
2. 选择当前网络连接
3. 点击 **高级** → **代理**
4. 勾选 **网页代理(HTTP)** 和 **安全网页代理(HTTPS)**
5. 服务器填写: `127.0.0.1`
6. 端口填写: `8888`
7. 点击 **好** → **应用**

---

## 增强模式 (TUN)

TUN 模式可以代理所有流量，包括不支持代理的应用。

**注意**: 需要 root 权限

### 启用

```bash
# 通过 API
curl -X POST http://localhost:9090/api/tun/enable

# 查看状态
curl http://localhost:9090/api/tun/status
```

### 禁用

```bash
curl -X POST http://localhost:9090/api/tun/disable
```

---

## 代理测试

### 延迟测试

```bash
# 测试所有代理
curl http://localhost:9090/api/test/all

# 测试特定代理
curl -X POST http://localhost:9090/api/test/proxy \
  -H "Content-Type: application/json" \
  -d '{"name": "VMess-1", "url": "http://www.gstatic.com/generate_204"}'
```

### 验证代理是否工作

```bash
# 通过代理访问
curl -x http://127.0.0.1:8888 http://myip.ipip.net

# SOCKS5 代理
curl -x socks5://127.0.0.1:8888 http://myip.ipip.net
```

---

## 统计信息

### 实时统计

```bash
curl http://localhost:9090/api/stats
```

### WebSocket 订阅

```javascript
const ws = new WebSocket('ws://localhost:9090/ws');
ws.onmessage = (event) => {
  const stats = JSON.parse(event.data);
  console.log('Upload:', stats.upload_speed);
  console.log('Download:', stats.download_speed);
};
```

---

## 日志查看

### 日志级别

在 `surge.conf` 中设置：

```ini
[General]
# verbose - 详细
# info - 信息
# notify - 通知（默认）
# warning - 警告
loglevel = notify
```

### 查看日志

服务启动后，日志会输出到终端。

---

## 规则管理

### 基本规则

```ini
[Rule]
# 域名匹配
DOMAIN,google.com,Proxy

# 域名后缀
DOMAIN-SUFFIX,youtube.com,Proxy

# IP 段
IP-CIDR,192.168.0.0/16,DIRECT

# GeoIP
GEOIP,CN,DIRECT

# 最终规则
FINAL,Proxy
```

### 规则测试

```bash
# 测试某个域名匹配哪条规则
curl http://localhost:9090/api/test/rule?domain=google.com
```

---

## 代理链

创建链式代理，流量依次通过多个代理服务器。

```ini
[Proxy Group]
Chain = relay, Proxy1, Proxy2, Proxy3
```

使用场景：
- 增加匿名性
- 绕过多重封锁
- 访问特定区域内容

---

## 订阅管理

### 添加订阅

```ini
[Proxy Group]
Subscription = select, policy-path=https://example.com/sub.txt, update-interval=86400
```

### 更新订阅

```bash
# API 方式
curl -X POST http://localhost:9090/api/subscription/update
```

---

## 性能优化

### DNS 优化

```ini
[General]
# 使用快速的 DNS 服务器
dns-server = 223.5.5.5, 119.29.29.29

# 启用 DoH
encrypted-dns-server = https://dns.alidns.com/dns-query
```

### 代理测试优化

```ini  
test-timeout = 3
```

### 跳过代理优化

```ini
skip-proxy = 127.0.0.1, 192.168.0.0/16, 10.0.0.0/8, *.local, localhost
```

---

## 故障排除

### 代理无法连接

1. 检查代理配置是否正确
2. 测试代理服务器是否在线
3. 检查防火墙设置
4. 查看日志错误信息

```bash
# 查看代理状态
curl http://localhost:9090/api/proxies

# 测试代理
curl -X POST http://localhost:9090/api/test/proxy \
  -d '{"name": "VMess-1"}'
```

### 规则不生效

1. 检查规则顺序（从上到下匹配）
2. 确保 FINAL 规则在最后
3. 测试规则匹配

```bash
# 测试规则
curl "http://localhost:9090/api/test/rule?domain=google.com"
```

### DNS 解析问题

1. 检查 DNS 服务器配置
2. 尝试使用不同的 DNS
3. 清除 DNS 缓存

```bash
# macOS 清除 DNS 缓存
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

### 系统代理不生效

```bash
# macOS 检查系统代理设置
networksetup -getwebproxy Wi-Fi
networksetup -getsecurewebproxy Wi-Fi

# 重新设置
curl -X POST http://localhost:9090/api/system-proxy/disable
curl -X POST http://localhost:9090/api/system-proxy/enable -d '{"port": 8888}'
```

---

## 高级用法

### 自定义 DNS

```ini
[Host]
# 指定域名的 DNS
example.com = server:8.8.8.8

# IP 映射
api.example.com = 1.2.3.4
```

### URL 重写

```ini
[URL Rewrite]
# 重定向
^http://old\.com http://new.com 302

# 拦截广告
^http://ad\.example\.com - reject
```

### MITM 解密

```ini
[MITM]
hostname = *.example.com
skip-server-cert-verify = false
```

需要安装 CA 证书才能使用 MITM 功能。

---

## 安全建议

1. **不要在公共网络使用未加密的代理**
2. **定期更新代理服务器配置**
3. **谨慎使用 skip-cert-verify=true**
4. **保护好配置文件**（包含敏感信息）
5. **使用强密码**
6. **定期检查日志异常**

---

## 开机自启动

### macOS (launchd)

创建 `~/Library/LaunchAgents/com.surge.proxy.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.surge.proxy</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/surge-go</string>
        <string>-c</string>
        <string>/path/to/surge.conf</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

加载服务：

```bash
launchctl load ~/Library/LaunchAgents/com.surge.proxy.plist
```

---

## 配置示例

完整的配置示例见 [surge.conf](../surge.conf) 文件。

---

## 更多信息

- [API 文档](API.md)
- [配置文档](CONFIG.md)
- [GitHub 仓库](https://github.com/surge-proxy/surge-go)

---

## 获取帮助

如有问题，请：
1. 查看日志文件
2. 检查配置文件
3. 访问 GitHub Issues
4. 查阅文档
