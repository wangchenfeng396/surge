# 核心功能测试指南 (Core Features)

本指南涵盖 Surge Go 后端的基础代理与路由功能测试。

## 1. 代理服务连通性 (Proxy Connectivity)

### 端口说明
- **HTTP Proxy**: 默认 `8888`
- **SOCKS5 Proxy**: 默认 `8889`
- **API Server**: 默认 `9090`

### 测试方法
设置环境变量或直接指定代理发起请求。

```bash
# 测试 HTTP 代理转发
curl -v -x http://127.0.0.1:8888 https://www.google.com

# 测试 SOCKS5 代理转发
curl -v --socks5 127.0.0.1:8889 https://www.google.com
```

**预期结果:**
- 返回 `200 OK` 及网页内容。
- 日志显示 `Proxy Request: ... -> ProxyName`。

## 2. 规则路由验证 (Rule Routing)

验证后端的规则引擎是否按照 `surge.conf` 正确分流。

### 方法 A: 使用 API 模拟 (推荐)
无需实际网络连接，直接测试逻辑。

```bash
# 1. 测试域名后缀 (DOMAIN-SUFFIX)
curl -X POST http://127.0.0.1:9090/api/rules/match \
  -d '{"url": "https://www.google.com"}'
# 预期: adapter: "Proxy" (或对应策略组)

# 2. 测试 IP 段 (IP-CIDR)
curl -X POST http://127.0.0.1:9090/api/rules/match \
  -d '{"url": "http://192.168.1.5", "source_ip": "192.168.1.100"}'
# 预期: adapter: "DIRECT"
```

### 方法 B: 实际访问测试
访问特定测试站点验证 IP。

```bash
# 访问 ip.sb (应走代理 IP)
curl -x http://127.0.0.1:8888 https://api.ip.sb/ip

# 访问国内站点 (应直连，走本地 IP)
curl -x http://127.0.0.1:8888 https://www.baidu.com
```

## 3. 策略组控制 (Policy Groups)

测试切换策略组节点是否生效。

### 列出策略组
```bash
curl http://127.0.0.1:9090/api/config/proxy-groups
```

### 切换节点
```bash
# 将 "Proxy" 组切换到 "US-Node"
curl -X POST http://127.0.0.1:9090/api/config/proxy-groups/Proxy/select \
  -d '{"proxy": "US-Node"}'
```

**验证:**
再次访问 `https://api.ip.sb/ip`，IP 应变更为 US 节点的 IP。
