# WebSocket 实时更新功能说明

## 概述

WebSocket 实时更新功能已在项目中完全实现，提供后端到前端的实时数据推送能力。

---

## 架构

### 后端 (surge-go)

**端点**: `ws://localhost:9090/ws`

后端通过 WebSocket 推送实时数据到前端，包括：
- 流量统计（上传/下载速度、总流量）
- 连接数
- 代理状态变化

### 前端 (SurgeProxy)

**文件**: `Services/WebSocketClient.swift`

```swift
class WebSocketClient: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var latestStats: NetworkStats?
    
    func connect()
    func disconnect()
    func send(_ message: String)
}
```

---

## 功能特性

### ✅ 已实现功能

#### 1. 自动连接
- 代理启动时自动连接 WebSocket
- 集成在 `GoProxyManager` 中

```swift
// GoProxyManager.swift Line 256-257
// Connect WebSocket for real-time updates
wsClient.connect()
```

#### 2. 实时数据推送
- 接收并解析 JSON 格式的统计数据
- 自动更新 UI 显示

```swift
// WebSocketClient.swift Line 198-206
wsClient.$latestStats
    .compactMap { $0 }
    .receive(on: DispatchQueue.main)
    .sink { [weak self] stats in
        self?.updateWithStats(stats)
    }
    .store(in: &cancellables)
```

#### 3. 自动重连机制
- 连接断开时自动尝试重连
- 最多重试 5 次
- 渐进式延迟（1秒、2秒、3秒...）

```swift
// WebSocketClient.swift Line 50-64
private func reconnect() {
    guard reconnectAttempts < maxReconnectAttempts else {
        print("Max reconnect attempts reached")
        return
    }
    
    reconnectAttempts += 1
    print("Reconnecting... attempt \(reconnectAttempts)")
    
    disconnect()
    
    DispatchQueue.main.asyncAfter(deadline: .now() + Double(reconnectAttempts)) {
        self.connect()
    }
}
```

#### 4. 消息处理
- 支持 String 和 Data 类型消息
- JSON 自动解码
- 错误处理

```swift
// WebSocketClient.swift Line 82-95
private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
    switch message {
    case .string(let text):
        parseStatsUpdate(text)
        
    case .data(let data):
        if let text = String(data: data, encoding: .utf8) {
            parseStatsUpdate(text)
        }
        
    @unknown default:
        break
    }
}
```

#### 5. 流量统计显示
- 上传/下载速度
- 总上传/下载流量
- 活动连接数

```swift
@Published var latestStats: NetworkStats?

struct NetworkStats: Codable {
    let upload: Int
    let download: Int
    let uploadSpeed: Int
    let downloadSpeed: Int
    let connections: Int
}
```

---

## 使用方式

### 启动 WebSocket 连接

```swift
// 自动启动
// 当用户点击"启动代理"时，WebSocket 会自动连接

proxyManager.startProxy()
// ↓ 内部调用
wsClient.connect()
```

### 接收实时更新

```swift
// 在 SwiftUI View 中
@StateObject var proxyManager = GoProxyManager()

var body: some View {
    VStack {
        // 流量统计自动从 WebSocket 更新
        Text("Upload: \(formatBytes(proxyManager.totalUpload))")
        Text("Download: \(formatBytes(proxyManager.totalDownload))")
        Text("Speed: ↑ \(formatSpeed(proxyManager.uploadSpeed))")
        Text("Connections: \(proxyManager.connections)")
    }
}
```

### 停止连接

```swift
// 自动停止
// 当用户点击"停止代理"时，WebSocket 会自动断开

proxyManager.stopProxy()
// ↓ 内部调用
wsClient.disconnect()
```

---

## 数据格式

### 后端推送格式

```json
{
  "upload": 1048576,
  "download": 2097152,
  "upload_speed": 102400,
  "download_speed": 204800,
  "connections": 5
}
```

### 前端解析

```swift
struct NetworkStats: Codable {
    let upload: Int           // 总上传字节数
    let download: Int         // 总下载字节数
    let uploadSpeed: Int      // 上传速度 (bytes/s)
    let downloadSpeed: Int    // 下载速度 (bytes/s)
    let connections: Int      // 活动连接数
    
    enum CodingKeys: String, CodingKey {
        case upload, download
        case uploadSpeed = "upload_speed"
        case downloadSpeed = "download_speed"
        case connections
    }
}
```

---

## 状态管理

### 连接状态

```swift
@Published var isConnected = false

// UI 中显示连接状态
if wsClient.isConnected {
    Image(systemName: "checkmark.circle.fill")
        .foregroundColor(.green)
} else {
    Image(systemName: "xmark.circle.fill")
        .foregroundColor(.red)
}
```

### 重连状态

```swift
private var reconnectAttempts = 0
private let maxReconnectAttempts = 5

// 失败时显示重连次数
Text("Reconnecting... (\(reconnectAttempts)/\(maxReconnectAttempts))")
```

---

## 调试

### 启用 WebSocket 日志

```swift
// WebSocketClient.swift
// 所有关键操作都有日志输出

print("WebSocket connected")
print("WebSocket disconnected")
print("WebSocket receive error: \(error)")
print("Failed to decode stats: \(error)")
```

### 测试 WebSocket

1. 启动后端: `./surge-go -c surge.conf`
2. 使用 wscat 测试:
```bash
npm install -g wscat
wscat -c ws://localhost:9090/ws
```

3. 观察日志输出

---

## 性能考虑

### 更新频率
- 后端推送频率: 约每秒 1 次
- UI 更新: 通过 Combine 自动批处理
- 内存占用: 最小化，仅保留最新数据

### 线程安全
- 所有 `@Published` 属性在主线程更新
- WebSocket 操作在后台线程
- 使用 `DispatchQueue.main.async` 确保线程安全

```swift
DispatchQueue.main.async {
    self.latestStats = stats
}
```

---

## 故障排除

### WebSocket 无法连接

**问题**: `WebSocket receive error: Connection refused`

**解决**:
1. 确认后端正在运行: `curl http://localhost:9090/api/health`
2. 检查防火墙设置
3. 查看后端日志

### 频繁断线重连

**问题**: WebSocket 连接不稳定

**解决**:
1. 检查网络连接
2. 增加重连延迟
3. 检查后端负载

### 数据不更新

**问题**: 前端收到数据但 UI 不更新

**解决**:
1. 确认 `@Published` 属性在主线程更新
2. 检查 Combine 订阅是否正常
3. 验证数据解码成功

---

## 扩展功能

### 添加更多消息类型

```swift
enum WSMessage: Codable {
    case stats(NetworkStats)
    case proxyStatus(ProxyStatus)
    case alert(String)
}

private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
    // 根据消息类型分发处理
    let wsMessage = try? JSONDecoder().decode(WSMessage.self, from: data)
    switch wsMessage {
    case .stats(let stats):
        updateStats(stats)
    case .proxyStatus(let status):
        updateProxyStatus(status)
    case .alert(let message):
        showAlert(message)
    }
}
```

### 双向通信

```swift
// 从前端发送命令到后端
wsClient.send("""
{
    "command": "switch_proxy",
    "proxy": "Auto"
}
""")
```

---

## 总结

✅ WebSocket 实时更新功能已完全实现并集成  
✅ 自动连接、重连机制完善  
✅ 流量统计实时显示  
✅ 线程安全，性能优化  

**状态**: 生产就绪 🚀
