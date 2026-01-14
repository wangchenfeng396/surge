# Protocol Package

统一的代理协议接口层，为所有代理协议（VMess、Trojan、VLESS 等）提供标准化接口。

## 核心接口

### Dialer

所有代理协议实现必须实现 `Dialer` 接口：

```go
type Dialer interface {
    DialContext(ctx context.Context, network, address string) (net.Conn, error)
    Name() string
    Type() string
    Test(url string, timeout time.Duration) (latency int, err error)
    Close() error
}
```

### ProxyConfig

通用的代理配置结构：

```go
type ProxyConfig struct {
    Name    string                 // 代理名称（必须唯一）
    Type    string                 // 协议类型：vmess, trojan, vless 等
    Server  string                 // 服务器地址
    Port    int                    // 服务器端口
    Options map[string]interface{} // 协议特定选项
}
```

### ConnectionManager

管理代理连接，提供连接池等优化功能：

```go
type ConnectionManager interface {
    Get(ctx context.Context, dialer Dialer, network, address string) (net.Conn, error)
    Put(dialer Dialer, conn net.Conn) error
    Close() error
    Stats() *ConnectionStats
}
```

## 内置实现

### DirectDialer

直连拨号器，不通过代理直接连接：

```go
dialer := protocol.NewDirectDialer("DIRECT")
conn, err := dialer.DialContext(ctx, "tcp", "example.com:443")
```

### RejectDialer

拒绝拨号器，用于实现 REJECT 策略：

```go
dialer := protocol.NewRejectDialer("REJECT")
conn, err := dialer.DialContext(ctx, "tcp", "example.com:443")
// err != nil, conn == nil
```

### SimpleConnectionManager

简单的连接管理器实现（暂无连接池）：

```go
manager := protocol.NewSimpleConnectionManager()
conn, err := manager.Get(ctx, dialer, "tcp", "example.com:443")
```

### SimpleTester

简单的延迟测试器：

```go
tester := protocol.NewSimpleTester(10 * time.Second)

// 测试单个代理
result := tester.Test(ctx, dialer, "http://www.google.com/generate_204")

// 测试多个代理
results := tester.TestMultiple(ctx, dialers, "http://www.google.com/generate_204")
```

## 使用示例

### 1. 创建代理配置

```go
config := &protocol.ProxyConfig{
    Name:   "my-proxy",
    Type:   "vmess",
    Server: "example.com",
    Port:   443,
    Options: map[string]interface{}{
        "uuid":     "12345678-1234-1234-1234-123456789012",
        "alterId":  64,
        "security": "auto",
        "tls":      true,
    },
}

// 验证配置
if err := config.Validate(); err != nil {
    log.Fatal(err)
}
```

### 2. 实现自定义 Dialer

```go
type MyProxyDialer struct {
    name   string
    server string
    port   int
}

func (d *MyProxyDialer) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
    // 1. 连接到代理服务器
    conn, err := net.Dial("tcp", fmt.Sprintf("%s:%d", d.server, d.port))
    if err != nil {
        return nil, err
    }
    
    // 2. 执行握手协议
    // ...
    
    // 3. 返回加密连接
    return conn, nil
}

func (d *MyProxyDialer) Name() string { return d.name }
func (d *MyProxyDialer) Type() string { return "myproxy" }
func (d *MyProxyDialer) Test(url string, timeout time.Duration) (int, error) { /* ... */ }
func (d *MyProxyDialer) Close() error { return nil }
```

### 3. 使用 Dialer

```go
// 创建 dialer
dialer := protocol.NewDirectDialer("DIRECT")

// 建立连接
ctx := context.Background()
conn, err := dialer.DialContext(ctx, "tcp", "example.com:443")
if err != nil {
    log.Fatal(err)
}
defer conn.Close()

// 使用连接
conn.Write([]byte("GET / HTTP/1.1\r\nHost: example.com\r\n\r\n"))
```

### 4. 测试代理延迟

```go
tester := protocol.NewSimpleTester(10 * time.Second)
result := tester.Test(context.Background(), dialer, "http://www.google.com/generate_204")

if result.Error != nil {
    fmt.Printf("Test failed: %v\n", result.Error)
} else {
    fmt.Printf("Latency: %v\n", result.Latency)
}
```

## 配置选项获取

`ProxyConfig` 提供了便捷的方法获取选项值：

```go
config := &protocol.ProxyConfig{
    Options: map[string]interface{}{
        "uuid":    "12345678-1234-1234-1234-123456789012",
        "alterId": 64,
        "tls":     true,
    },
}

// 获取字符串
uuid, ok := config.GetString("uuid")

// 获取整数
alterId, ok := config.GetInt("alterId")

// 获取布尔值
tls, ok := config.GetBool("tls")
```

## 错误处理

包提供了常用的错误类型：

```go
var (
    ErrInvalidConfig    = errors.New("invalid proxy configuration")
    ErrConnectionFailed = errors.New("connection failed")
    ErrTimeout          = errors.New("connection timeout")
    ErrAuthFailed       = errors.New("authentication failed")
)
```

## 统计信息

`ConnectionManager` 提供连接统计信息：

```go
stats := manager.Stats()
fmt.Printf("Active: %d\n", stats.Active)
fmt.Printf("Idle: %d\n", stats.Idle)
fmt.Printf("Total Opened: %d\n", stats.TotalOpened)
fmt.Printf("Total Closed: %d\n", stats.TotalClosed)
fmt.Printf("Total Reused: %d\n", stats.TotalReused)
```

## 下一步

接下来需要实现具体的协议：

1. **VMess**: `internal/protocol/vmess/`
2. **Trojan**: `internal/protocol/trojan/`
3. **VLESS**: `internal/protocol/vless/`

每个协议实现都应该：
- 实现 `Dialer` 接口
- 提供协议特定的配置结构
- 包含单元测试
- 包含使用示例

## 测试

运行测试：

```bash
go test -v ./internal/protocol/...
```

运行带覆盖率的测试：

```bash
go test -v -cover ./internal/protocol/...
```

## 性能考虑

当前实现是基础版本，后续可以优化：

1. **连接池**: 实现真正的连接池（目前 SimpleConnectionManager 不支持）
2. **零拷贝**: 使用 splice 等系统调用优化数据转发
3. **协程池**: 限制并发数，避免协程爆炸
4. **内存池**: 使用 sync.Pool 减少内存分配

## 参考

- [v2ray-core](https://github.com/v2fly/v2ray-core)
- [Xray-core](https://github.com/XTLS/Xray-core)
- [trojan-go](https://github.com/p4gefau1t/trojan-go)
