# SurgeProxy 代理测速功能技术文档

## 概述

本文档详细说明 SurgeProxy 应用中"Tap to Test"代理测速功能的完整实现逻辑、架构设计和数据流。

---

## 测试入口概览

SurgeProxy 提供了**4个不同的测试入口**，分别服务于不同场景：

### 1. 批量测速界面 (ProxyTestView)
- **位置**: [Views/ProxyTestView.swift](file:///Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/SurgeProxy/SurgeProxy/Views/ProxyTestView.swift)
- **用途**: 一次性测试所有代理节点
- **特点**: 支持自定义测试URL、批量测试、单节点重测

### 2. 实时延迟监控 (ActivityView - LatencyCardView)
- **位置**: [Views/ActivityView.swift](file:///Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/SurgeProxy/SurgeProxy/Views/ActivityView.swift) (第274-407行)
- **用途**: 首页自动显示 Router/DNS/Proxy 延迟
- **特点**: 自动刷新（5秒间隔）、手动刷新按钮

### 3. 诊断工具 (DiagnosticsView)
- **位置**: [Views/DiagnosticsView.swift](file:///Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/SurgeProxy/SurgeProxy/Views/DiagnosticsView.swift)
- **用途**: 综合网络诊断，包含网关、DNS、代理测试
- **特点**: Console风格日志输出、系统级诊断

### 4. 代理诊断对话框 (ProxyDiagnosticsView)
- **位置**: [Views/ProxyDiagnosticsView.swift](file:///Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/SurgeProxy/SurgeProxy/Views/ProxyDiagnosticsView.swift)
- **用途**: TCP/UDP/速度专项测试（**当前为模拟实现**）
- **特点**: 支持NAT类型检测、上下行速度测试

---

## 核心测试流程架构

```
┌──────────────┐
│  UI 触发     │ (用户点击测试按钮/自动触发)
└──────┬───────┘
       ▼
┌──────────────────────────────────────┐
│  APIClient.testProxy(name, url)      │
│  - 超时: 5秒 (用户可修改为20秒)      │
│  - 请求方法: POST                     │
│  - 端点: /api/proxy/test              │
└──────┬───────────────────────────────┘
       ▼
┌──────────────────────────────────────┐
│  Backend Handler                      │
│  handleTestProxy(w, r)                │
│  - 文件: internal/api/handlers.go     │
│  - 解析请求参数 (name, url)           │
└──────┬───────────────────────────────┘
       ▼
┌──────────────────────────────────────┐
│  Engine.TestProxy(name, url)          │
│  - 超时: 10秒                         │
│  - 文件: internal/engine/engine.go    │
│  - 查找代理实例                       │
└──────┬───────────────────────────────┘
       ▼
┌──────────────────────────────────────┐
│  Protocol Implementation              │
│  Dialer.Test(url, timeout)            │
│  - VMess: internal/protocol/vmess/    │
│  - Trojan: internal/protocol/trojan/  │
│  - VLESS: internal/protocol/vless/    │
│  - Direct: internal/protocol/direct.go│
└──────┬───────────────────────────────┘
       ▼
┌──────────────────────────────────────┐
│  HTTP Client 测试                     │
│  - 通过代理发起 HTTP GET 请求         │
│  - 测量往返时间 (RTT)                 │
│  - 返回延迟(ms)或错误                 │
└──────────────────────────────────────┘
```

---

## 详细实现分析

### 1. 前端层 (Swift)

#### APIClient.testProxy()
**文件**: [SurgeProxy/Services/APIClient.swift](file:///Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/SurgeProxy/SurgeProxy/Services/APIClient.swift) (行487-530)

```swift
func testProxy(name: String, url: String) async throws -> ProxyTestResponse {
    let endpoint = URL(string: "\(baseURL)/api/proxy/test")!
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // ⚠️ 关键配置: 超时时间
    request.timeoutInterval = 5  // 用户可能需要调整为20秒
    
    let body = [
        "name": name,
        "url": url
    ]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    let (data, _) = try await session.data(for: request)
    return try JSONDecoder().decode(ProxyTestResponse.self, from: data)
}
```

**关键点**:
- 默认超时 **5秒**（短于后端10秒，可能导致超时）
- 建议配置: `request.timeoutInterval = 20`

#### ProxyTestViewModel.measureLatency()
**文件**: [Views/ProxyTestView.swift](file:///Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/SurgeProxy/SurgeProxy/Views/ProxyTestView.swift) (行222-230)

```swift
private func measureLatency(proxyName: String) async -> Int? {
    do {
        let result = try await apiClient.testProxy(name: proxyName, url: testURL)
        return result.latency  // 返回毫秒值
    } catch {
        return nil  // 失败返回 nil
    }
}
```

**测试URL配置**:
- 默认: `http://www.gstatic.com/generate_204`
- 诊断工具: `http://cp.cloudflare.com/generate_204`
- 用户可在 General Config 中自定义

---

### 2. 后端层 (Go)

#### handleTestProxy
**文件**: [surge-go/internal/api/handlers.go](file:///Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/surge-go/internal/api/handlers.go) (行503-533)

```go
func (s *Server) handleTestProxy(w http.ResponseWriter, r *http.Request) {
    var req struct {
        Name string `json:"name"`
        URL  string `json:"url"`
    }
    json.NewDecoder(r.Body).Decode(&req)
    
    // 调用引擎测试
    latency, err := s.engine.TestProxy(req.Name, req.URL)
    
    if err != nil {
        respondJSON(w, map[string]interface{}{
            "success": false,
            "name":    req.Name,
            "error":   err.Error(),
        })
        return
    }
    
    respondJSON(w, map[string]interface{}{
        "success": true,
        "name":    req.Name,
        "latency": latency,  // 返回毫秒值
    })
}
```

#### Engine.TestProxy()
**文件**: [surge-go/internal/engine/engine.go](file:///Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/surge-go/internal/engine/engine.go) (行419-441)

```go
func (e *Engine) TestProxy(name, testURL string) (int, error) {
    if testURL == "" {
        testURL = "http://cp.cloudflare.com/generate_204"
    }
    
    // 查找代理实例
    var dialer protocol.Dialer
    if name == "DIRECT" {
        dialer = protocol.NewDirectDialer("DIRECT")
    } else if p, ok := e.Proxies[name]; ok {
        dialer = p
    } else if g, ok := e.Groups[name]; ok {
        dialer = g
    }
    
    if dialer == nil {
        return 0, fmt.Errorf("proxy or group not found: %s", name)
    }
    
    // ⚠️ 关键配置: 超时10秒
    return dialer.Test(testURL, 10*time.Second)
}
```

**特殊处理**:
- `DIRECT` 策略: 即时创建 DirectDialer
- 代理节点: 从 `e.Proxies` 查找
- 代理组: 从 `e.Groups` 查找

---

### 3. 协议实现层

#### VMess 测试实现
**文件**: [surge-go/internal/protocol/vmess/client.go](file:///Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/surge-go/internal/protocol/vmess/client.go) (行254-288)

```go
func (c *Client) Test(url string, timeout time.Duration) (int, error) {
    start := time.Now()
    
    ctx, cancel := context.WithTimeout(context.Background(), timeout)
    defer cancel()
    
    // 创建 HTTP 客户端，使用此代理
    client := &http.Client{
        Timeout: timeout,
        Transport: &http.Transport{
            DialContext: c.DialContext,  // 关键: 使用代理拨号
        },
        CheckRedirect: func(req *http.Request, via []*http.Request) error {
            return http.ErrUseLastResponse
        },
    }
    
    req, _ := http.NewRequestWithContext(ctx, "GET", url, nil)
    resp, err := client.Do(req)
    if err != nil {
        return 0, err
    }
    defer resp.Body.Close()
    
    io.Copy(io.Discard, resp.Body)  // 丢弃响应体
    
    latency := time.Since(start).Milliseconds()
    return int(latency), nil
}
```

**其他协议**: Trojan、VLESS、Direct 均采用相同模式

---

## 超时配置问题诊断

### 当前问题
用户报告超时错误 (`NSURLErrorDomain Code=-1001`)

### 超时层级分析

| 层级 | 组件 | 超时设置 | 说明 |
|------|------|----------|------|
| 1 | 前端 APIClient | **5秒** ❌ | 用户改回5秒，短于后端 |
| 2 | 后端 Engine | **10秒** ✅ | 代理测速超时 |
| 3 | 协议实现 | **10秒** ✅ | HTTP 请求超时 |

### 问题原因
**前端 < 后端**，导致前端提前超时

### 解决方案
```swift
// APIClient.swift 第499行
request.timeoutInterval = 20  // 推荐20秒
```

**推荐配置逻辑**:
- 前端超时 = 后端超时 + 网络延迟余量 (10s + 10s = 20s)

---

## WebSocket 握手问题修复

### 问题表现
```
WebSocket dial failed: websocket.Dial ws://...:443: bad status
```

### 根因分析
1. **错误协议头**: 未启用 TLS 时使用 `ws://` 连接 443 端口
2. **Origin 不匹配**: `Origin: http://...` 与 TLS 环境不符

### 修复措施 (已实施)

#### 1. Origin Header 动态设置
**文件**: [surge-go/internal/protocol/vmess/client.go](file:///Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/surge-go/internal/protocol/vmess/client.go) (行154-171)

```go
// 根据 TLS 配置动态设置 Origin Scheme
originScheme := "http"
if c.config.TLS {
    originScheme = "https"  // ✅ TLS 环境使用 https
}
origin := fmt.Sprintf("%s://%s", originScheme, c.config.Server)
if c.config.Host != "" {
    origin = fmt.Sprintf("%s://%s", originScheme, c.config.Host)
}

wsConfig, _ := websocket.NewConfig(uri, origin)

// Host Header Fallback
if c.config.Host != "" {
    wsConfig.Header.Set("Host", c.config.Host)
} else if c.config.SNI != "" {
    wsConfig.Header.Set("Host", c.config.SNI)  // ✅ 使用 SNI 作为备选
}
```

#### 2. TLS 配置解析增强
**文件**: [surge-go/internal/protocol/vmess/config.go](file:///Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/surge-go/internal/protocol/vmess/config.go) (行159-164)

```go
// Parse TLS
if tls, ok := cfg.GetBool("tls"); ok {
    vmessCfg.TLS = tls
} else if tlsStr, ok := cfg.GetString("tls"); ok && tlsStr == "true" {
    vmessCfg.TLS = true  // ✅ 兼容字符串类型
}
```

---

## 测试 URL 选择

### 常用测试端点

| URL | 特点 | 适用场景 |
|-----|------|----------|
| `http://cp.cloudflare.com/generate_204` | 稳定、全球CDN | **推荐** - 诊断工具默认 |
| `http://www.gstatic.com/generate_204` | Google服务 | ProxyTestView 默认 |
| `http://www.bing.com` | Microsoft服务 | Direct 测试 |
| `http://4.ipw.cn` | 返回IP | 用户curl测试 |

### 配置位置
- **代码层**: 各View默认值
- **用户层**: General Config -> Proxy Test URL

---

## 用户操作流程示例

### 场景1: 批量测速
1. 用户打开 **ProxyTestView**
2. (可选) 修改测试URL
3. 点击 **"测试全部"** 按钮
4. UI 显示每个代理的测速进度
5. 完成后显示延迟结果（绿色<100ms，橙色100-300ms，红色>300ms）

### 场景2: 单节点测速
1. 在 ProxyTestView 列表中找到目标代理
2. 点击该行右侧的 **播放按钮** ▶️
3. 等待测速完成
4. 查看延迟结果

### 场景3: 自动监控
1. 打开 App 首页 (ActivityView)
2. 查看 "Latency" 卡片
3. 系统每5秒自动刷新 Router/DNS/Proxy 延迟
4. (可选) 点击刷新按钮立即更新

---

## 调试清单

### 前端调试
```swift
// 1. 检查超时配置
print("🔍 APIClient: Testing proxy '\(name)' with URL: \(url)")
print("➡️ Request Body: \(bodyString)")
print("⏱️ Timeout: \(request.timeoutInterval) seconds")

// 2. 检查响应
print("⬅️ Response Status: \(httpResponse.statusCode)")
print("⬅️ Response Body: \(responseString)")
```

### 后端调试
```bash
# 1. 检查后端是否运行
curl http://localhost:19090/api/health

# 2. 手动测试代理
curl -X POST http://localhost:19090/api/proxy/test \
  -H "Content-Type: application/json" \
  -d '{"name":"MyHk","url":"http://cp.cloudflare.com/generate_204"}'

# 3. 查看代理列表
curl http://localhost:19090/api/config/proxies
```

### 配置验证
```bash
# 检查 surge.conf 中的代理配置
cat ~/Library/Application\ Support/SurgeProxy/surge.conf | grep -A5 "^\[Proxy\]"
```

---

## 已知问题与解决方案

### 1. ❌ Shadowsocks 未实现
**现象**: SS代理测试失败
**原因**: [surge-go/internal/engine/proxies.go](file:///Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/surge-go/internal/engine/proxies.go) 返回 "not implemented"
**影响**: 只有 VMess/Trojan/VLESS 可测

### 2. ✅ DIRECT 测速已修复
**修复**: Engine 特殊处理 "DIRECT" 策略

### 3. ✅ VMess WebSocket 已修复
**修复**: Origin Header 动态 scheme + Host fallback

### 4. ⚠️ 前端超时配置不足
**建议**: 将 `request.timeoutInterval` 改为 20 秒

---

## 配置建议

### 生产环境
```swift
// APIClient.swift
request.timeoutInterval = 20  // 允许慢速代理

// Engine.go
return dialer.Test(testURL, 15*time.Second)  // 增加后端容忍度
```

### 调试环境
```swift
request.timeoutInterval = 30  // 更长超时便于调试
```

---

## 总结

SurgeProxy 的代理测速功能采用**前后端分离架构**：
- **前端**: Swift/SwiftUI UI + APIClient 网络层
- **后端**: Go Engine + Protocol 抽象层
- **关键路径**: UI → APIClient (5s) → Handler → Engine (10s) → Protocol.Test

**核心优化点**:
1. ✅ 超时配置对齐 (前端20s >= 后端10s)
2. ✅ WebSocket TLS 适配 (Origin + Host)
3. ✅ 测试URL优化 (Cloudflare CDN)
4. ⚠️ SS协议待实现

**调试优先级**:
1. 检查前端超时 >= 后端超时 + 5s
2. 验证代理配置 TLS 字段正确解析
3. 确认测试URL可达性
4. 查看后端日志排查协议错误
