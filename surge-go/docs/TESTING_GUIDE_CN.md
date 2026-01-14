# 分流规则测试指南 (Routing & Rule Testing Guide)

当后端服务单独运行时，您可以通过以下三种方式测试分流效果：

## 1. 使用 API 直接查询 (推荐)
后端提供了一个专用 API 用于测试给定 URL 会匹配到哪条规则和策略，无需实际发送网络请求。

**请求方式:** `POST /api/rules/match`

**示例命令:**
```bash
# 测试 Google 访问 (应匹配 Proxy 或 AI 策略)
curl -X POST http://127.0.0.1:9090/api/rules/match \
  -d '{"url": "https://www.google.com"}'

# 测试局域网访问 (应匹配 DIRECT)
curl -X POST http://127.0.0.1:9090/api/rules/match \
  -d '{"url": "http://192.168.1.100", "source_ip": "192.168.1.50"}'
```

**响应示例:**
```json
{
  "adapter": "Proxy",
  "rule": "DOMAIN-SUFFIX,google.com"
}
```

## 2. 通过代理端口测试 (实际请求)
配置 `curl` 使用 Surge 的 HTTP 代理端口 (默认 8888) 发送实际请求，观察连接情况。

**示例:**
```bash
# 通过代理访问
export http_proxy=http://127.0.0.1:8888
export https_proxy=http://127.0.0.1:8888

# 测试连接
curl -v https://www.google.com
curl -v https://baidu.com
```

## 3. 运行自动化验证套件
项目包含一个完整的配置验证工具，可批量测试所有规则。

**运行命令:**
```bash
go test -v ./cmd/config_verification/...
```
这会加载 `surge.conf` 并对关键规则进行回归测试。

## 4. 查看实时日志
在启动后端时，确保日志级别包含 `notify` 或 `info`，可以在终端看到实时的路由决策日志。

```text
[INFO] Proxy Request: www.google.com:443 -> Proxy (Rule: DOMAIN-SUFFIX, google.com)
```
