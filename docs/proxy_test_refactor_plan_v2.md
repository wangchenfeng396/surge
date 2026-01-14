# 代理测试方案对比与实施文档

## 文档信息
- **创建时间**: 2026-01-13
- **版本**: v2.0
- **决策**: 采用方案B - 通过代理服务器测试

---

## 问题背景

### 用户发现的问题
通过 `curl -x http://127.0.0.1:8888` 测试代理成功，但 App 内的测试功能失败。

```bash
# 成功案例
curl -v -x http://127.0.0.1:8888 http://4.ipw.cn
# 返回: 47.240.172.92 (正常)

# 失败案例
App 点击测试 → /api/proxy/test → 超时/失败
```

### 根本原因分析

#### 当前架构（方案A）的问题

```
┌─────────────┐
│  Frontend   │
└──────┬──────┘
       │ POST /api/proxy/test
       ▼
┌─────────────────────────┐
│  Backend Handler        │
└──────┬──────────────────┘
       │ Engine.TestProxy(name, url)
       ▼
┌─────────────────────────┐
│  Dialer.Test()          │
│  - 直接通过协议层连接   │ ❌ 绕过代理服务器
│  - 自己实现HTTP客户端   │
└─────────────────────────┘
```

**问题**:
1. **绕过代理服务器**: 不经过 HTTP/SOCKS5 服务器(8888端口)
2. **不走真实链路**: 无法测试策略组、规则匹配等
3. **协议实现细节**: 依赖VMess/Trojan等协议的正确实现（之前有WebSocket握手问题）
4. **无法验证端到端**: 测试的不是用户真实使用的路径

#### curl 成功的原因

```
┌──────────┐
│   curl   │
└────┬─────┘
     │ -x http://127.0.0.1:8888
     ▼
┌─────────────────────────┐
│  Proxy Server (8888)    │  ✅ 真实代理服务器
│  - 解析HTTP请求         │
│  - 匹配规则             │
│  - 选择出站代理         │
└────┬────────────────────┘
     │
     ▼
┌─────────────────────────┐
│  Selected Proxy         │
│  (e.g., MyHk)           │
└─────────────────────────┘
```

**优势**:
- 测试**完整代理链路**
- 包含所有中间件处理
- 符合真实使用场景

---

## 方案对比

### 方案A：直接协议层测试（当前）

**实现**:
```go
// Engine.TestProxy
func (e *Engine) TestProxy(name, testURL string) (int, error) {
    dialer := e.Proxies[name]  // 直接获取Dialer
    return dialer.Test(testURL, 10*time.Second)  // 直接调用
}

// VMess.Test
func (c *Client) Test(url string, timeout time.Duration) (int, error) {
    client := &http.Client{
        Transport: &http.Transport{
            DialContext: c.DialContext,  // ❌ 绕过代理服务器
        },
    }
    // ...
}
```

**优点**:
- 实现简单
- 不依赖代理服务器运行

**缺点**:
- ❌ 不测试真实链路
- ❌ 协议实现Bug会导致失败
- ❌ 无法测试策略组逻辑
- ❌ 无法验证规则匹配

---

### 方案B：通过代理服务器测试（新方案）✅

**架构**:
```
┌─────────────┐
│  Frontend   │
└──────┬──────┘
       │ POST /api/proxy/test-live
       ▼
┌─────────────────────────────────┐
│  Backend Handler                │
│  1. 临时切换到指定代理          │
│  2. 通过127.0.0.1:8888测试      │
│  3. 恢复原配置                  │
└──────┬──────────────────────────┘
       │ client.Get via Proxy
       ▼
┌─────────────────────────────────┐
│  Proxy Server (8888)            │ ✅ 真实服务器
└──────┬──────────────────────────┘
       │
       ▼
┌─────────────────────────────────┐
│  Target Proxy (MyHk)            │
└─────────────────────────────────┘
```

**实现**:
```go
func (s *Server) handleTestProxyLive(w http.ResponseWriter, r *http.Request) {
    var req struct {
        Name string `json:"name"`
        URL  string `json:"url"`
    }
    json.NewDecoder(r.Body).Decode(&req)
    
    // 1. 保存当前配置
    oldMode := s.engine.GetMode()
    
    // 2. 临时切换到Global模式，指向目标代理
    s.engine.SetMode("global")
    s.engine.SetGlobalProxy(req.Name)  // 新增方法
    
    // 3. 通过本地代理端口测试
    start := time.Now()
    proxyURL, _ := url.Parse("http://127.0.0.1:8888")
    client := &http.Client{
        Transport: &http.Transport{
            Proxy: http.ProxyURL(proxyURL),
        },
        Timeout: 5 * time.Second,  // ✅ 用户要求5秒
    }
    
    testURL := req.URL
    if testURL == "" {
        testURL = "http://cp.cloudflare.com/generate_204"
    }
    
    resp, err := client.Get(testURL)
    latency := time.Since(start).Milliseconds()
    
    // 4. 恢复原配置
    s.engine.SetMode(oldMode)
    
    // 5. 返回结果
    if err != nil {
        respondJSON(w, map[string]interface{}{
            "success": false,
            "error":   err.Error(),
        })
        return
    }
    defer resp.Body.Close()
    
    respondJSON(w, map[string]interface{}{
        "success": true,
        "latency": int(latency),
    })
}
```

**优点**:
- ✅ 测试**真实代理链路**
- ✅ 包含所有中间件逻辑
- ✅ 与用户实际使用一致
- ✅ 不依赖协议层实现细节
- ✅ 可验证端到端功能

**缺点**:
- 需要临时修改Engine配置（已解决：快速切换+恢复）
- 并发测试需要加锁（可接受）

---

## 实施方案B

### Phase 1: Backend 实现

#### Task 1.1: Engine 添加配置切换方法

**文件**: `surge-go/internal/engine/engine.go`

```go
// SetGlobalProxy 临时设置全局代理（用于测试）
func (e *Engine) SetGlobalProxy(proxyName string) error {
    e.mu.Lock()
    defer e.mu.Unlock()
    
    // 验证代理存在
    if _, ok := e.Proxies[proxyName]; !ok {
        if _, ok := e.Groups[proxyName]; !ok {
            return fmt.Errorf("proxy not found: %s", proxyName)
        }
    }
    
    e.currentGlobalProxy = proxyName
    return nil
}

// ClearGlobalProxy 清除临时全局代理
func (e *Engine) ClearGlobalProxy() {
    e.mu.Lock()
    defer e.mu.Unlock()
    e.currentGlobalProxy = ""
}
```

#### Task 1.2: 新增 API 端点

**文件**: `surge-go/internal/api/handlers.go`

```go
func (s *Server) handleTestProxyLive(w http.ResponseWriter, r *http.Request) {
    var req struct {
        Name string `json:"name"`
        URL  string `json:"url"`
    }
    
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }
    
    if req.Name == "" {
        http.Error(w, "name parameter required", http.StatusBadRequest)
        return
    }
    
    // 保存当前模式
    oldMode := s.engine.GetMode()
    
    // 临时切换到Global模式并设置代理
    s.engine.SetMode("global")
    if err := s.engine.SetGlobalProxy(req.Name); err != nil {
        s.engine.SetMode(oldMode)
        respondJSON(w, map[string]interface{}{
            "success": false,
            "error":   err.Error(),
        })
        return
    }
    
    // 确保恢复配置
    defer func() {
        s.engine.ClearGlobalProxy()
        s.engine.SetMode(oldMode)
    }()
    
    // 通过本地代理端口测试
    start := time.Now()
    
    proxyURL, _ := url.Parse("http://127.0.0.1:8888")
    client := &http.Client{
        Transport: &http.Transport{
            Proxy: http.ProxyURL(proxyURL),
        },
        Timeout: 5 * time.Second,
    }
    
    testURL := req.URL
    if testURL == "" {
        testURL = "http://cp.cloudflare.com/generate_204"
    }
    
    resp, err := client.Get(testURL)
    latency := time.Since(start).Milliseconds()
    
    if err != nil {
        respondJSON(w, map[string]interface{}{
            "success": false,
            "error":   err.Error(),
        })
        return
    }
    defer resp.Body.Close()
    
    // 读取并丢弃响应体
    io.Copy(io.Discard, resp.Body)
    
    respondJSON(w, map[string]interface{}{
        "success": true,
        "latency": int(latency),
    })
}
```

#### Task 1.3: 注册路由

**文件**: `surge-go/internal/api/server.go`

```go
// 在 setupRoutes 中添加
s.router.HandleFunc("/api/proxy/test-live", s.handleTestProxyLive).Methods("POST")
```

---

### Phase 2: Frontend 实现

#### Task 2.1: 更新 APIClient

**文件**: `SurgeProxy/Services/APIClient.swift`

```swift
// 新方法：通过代理服务器测试
func testProxyLive(name: String, url: String = "http://cp.cloudflare.com/generate_204") async throws -> ProxyTestResponse {
    let endpoint = URL(string: "\(baseURL)/api/proxy/test-live")!
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    // 6秒超时（后端5秒 + 1秒网络余量）
    request.timeoutInterval = 6
    
    let body = [
        "name": name,
        "url": url
    ]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    let (data, _) = try await session.data(for: request)
    return try JSONDecoder().decode(ProxyTestResponse.self, from: data)
}

// 保留旧方法作为备选
func testProxy(name: String, url: String) async throws -> ProxyTestResponse {
    // 现在调用新方法
    return try await testProxyLive(name: name, url: url)
}
```

#### Task 2.2: 更新 ProxyTestViewModel

**文件**: `SurgeProxy/Views/ProxyTestView.swift`

```swift
private func measureLatency(proxyName: String) async -> (latency: Int?, error: String?) {
    do {
        // 调用新的Live测试API
        let result = try await apiClient.testProxyLive(name: proxyName, url: testURL)
        return (result.latency, result.error)
    } catch let error as NSError {
        // 提取具体错误信息
        if error.code == -1001 {
            return (nil, "请求超时 (>5s)")
        } else if error.code == -1009 {
            return (nil, "无网络连接")
        } else {
            return (nil, "连接失败")
        }
    }
}
```

---

### Phase 3: 测试与验证

#### 验收标准

1. ✅ 通过代理服务器端口(8888)测试
2. ✅ 5秒超时
3. ✅ 测试结果与 `curl -x` 一致
4. ✅ 并发测试不冲突
5. ✅ 失败后正确恢复配置

#### 测试用例

```bash
# 1. 启动App和代理服务器
# 2. 后端测试
curl -X POST http://localhost:19090/api/proxy/test-live \
  -H "Content-Type: application/json" \
  -d '{"name":"MyHk","url":"http://4.ipw.cn"}'

# 预期响应
{
  "success": true,
  "latency": 125
}

# 3. 前端测试
# 在ProxyTestView中点击测试按钮
# 预期：显示绿色延迟数字

# 4. 对比验证
curl -v -x http://127.0.0.1:8888 http://4.ipw.cn
# 应返回相同的IP和类似的延迟
```

---

## 关键改进

### 1. 超时配置统一

| 层级 | 组件 | 超时 | 原因 |
|------|------|------|------|
| Backend | HTTP Client | **5秒** | 用户要求 |
| Frontend | APIClient | **6秒** | 后端5秒 + 1秒余量 |

### 2. 测试URL

- **默认**: `http://cp.cloudflare.com/generate_204`
- **可选**: `http://4.ipw.cn` (返回IP)
- **用户自定义**: 通过参数传递

### 3. 并发控制

```go
// Engine添加测试锁
type Engine struct {
    // ...
    testMutex sync.Mutex  // 防止并发测试冲突
}

func (s *Server) handleTestProxyLive(w http.ResponseWriter, r *http.Request) {
    s.engine.testMutex.Lock()
    defer s.engine.testMutex.Unlock()
    
    // ... 测试逻辑
}
```

---

## 风险评估

### 风险1: 配置切换冲突
**影响**: 中
**缓解**: 
- 添加互斥锁
- 快速恢复机制（defer）

### 风险2: 代理服务器未运行
**影响**: 高
**缓解**: 
- 测试前检查端口是否监听
- 返回明确错误信息

### 风险3: 5秒超时不够
**影响**: 低
**缓解**: 
- 用户可调整（配置项）
- 错误提示建议延长

---

## 时间估算

| Phase | 任务数 | 预计时间 |
|-------|--------|----------|
| Phase 1 | 3 | 3小时 |
| Phase 2 | 2 | 2小时 |
| Phase 3 | - | 1小时 |
| **总计** | **5** | **6小时** |

---

## 决策记录

**日期**: 2026-01-13  
**决策**: 采用方案B - 通过代理服务器测试  
**理由**:
1. 与 `curl -x` 一致的测试路径
2. 测试真实代理链路
3. 解决协议层实现细节问题
4. 符合用户实际使用场景

**批准**: 用户确认 "好 按照方案B来实施"
