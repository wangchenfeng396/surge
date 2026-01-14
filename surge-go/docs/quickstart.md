# 快速开始指南

本文档提供从 sing-box 迁移到自研后端的快速启动指南。

## 📋 前置准备

### 1. 环境要求
- Go 1.21+ 
- macOS (当前项目针对 macOS 开发)
- 基础的 Go 开发知识

### 2. 依赖安装

```bash
# 安装必要的 Go 依赖
go mod tidy
```

---

## 🎯 第一步: 理解现有架构

### 当前架构 (sing-box 模式)

```
surge-go (当前)
├── 读取 Surge 配置
├── 转换为 sing-box JSON 配置
└── 启动 sing-box 核心
```

### 目标架构 (自研后端)

```
surge-go (目标)
├── 读取 Surge 配置
├── 直接使用自研代理引擎
│   ├── HTTP/SOCKS5 服务器
│   ├── 规则引擎
│   ├── 策略组管理
│   └── 协议客户端 (VMess/Trojan/VLESS)
└── HTTP API 服务
```

---

## 🚀 快速实施步骤

### 步骤 1: 创建核心接口

创建统一的代理客户端接口，这是整个架构的基础。

**文件**: `internal/protocol/dialer.go`

```go
package protocol

import (
    "context"
    "net"
)

// Dialer 定义代理客户端接口
type Dialer interface {
    // DialContext 拨号到目标地址
    DialContext(ctx context.Context, network, address string) (net.Conn, error)
    
    // Name 返回代理名称
    Name() string
    
    // Test 测试代理延迟
    Test(url string, timeout int) (int, error)
}

// ProxyConfig 代理配置
type ProxyConfig struct {
    Name     string
    Type     string // vmess, trojan, vless
    Server   string
    Port     int
    Options  map[string]interface{}
}
```

### 步骤 2: 实现第一个协议 (VMess)

从 VMess 开始，因为它是最常用的协议。

**建议**: 使用 v2ray-core 的 VMess 实现作为参考

```bash
# 创建 VMess 目录
mkdir -p internal/protocol/vmess

# 需要实现的文件:
# - client.go (主要客户端)
# - handshake.go (握手协议)
# - aead.go (加密)
# - websocket.go (WebSocket 传输)
```

**核心代码结构** (`internal/protocol/vmess/client.go`):

```go
package vmess

import (
    "context"
    "net"
    "github.com/surge-proxy/surge-go/internal/protocol"
)

type Client struct {
    name     string
    server   string
    port     int
    uuid     string
    alterId  int
    security string
    // ... 其他配置
}

func NewClient(cfg *protocol.ProxyConfig) (*Client, error) {
    // 初始化 VMess 客户端
}

func (c *Client) DialContext(ctx context.Context, network, address string) (net.Conn, error) {
    // 1. 连接到 VMess 服务器
    // 2. 执行 VMess 握手
    // 3. 返回加密连接
}
```

### 步骤 3: 实现简单的 HTTP 代理服务器

创建一个最简单的 HTTP CONNECT 代理服务器。

**文件**: `internal/server/http.go`

```go
package server

import (
    "bufio"
    "io"
    "net"
    "net/http"
)

type HTTPServer struct {
    addr   string
    dialer protocol.Dialer // 代理客户端
}

func (s *HTTPServer) Start() error {
    ln, err := net.Listen("tcp", s.addr)
    if err != nil {
        return err
    }
    
    for {
        conn, err := ln.Accept()
        if err != nil {
            continue
        }
        go s.handleConnection(conn)
    }
}

func (s *HTTPServer) handleConnection(conn net.Conn) {
    defer conn.Close()
    
    // 1. 解析 HTTP CONNECT 请求
    // 2. 使用 dialer 连接到目标
    // 3. 转发数据
}
```

### 步骤 4: 集成到主程序

修改 `cmd/surge/main.go`，移除 sing-box 依赖。

```go
package main

import (
    "log"
    "github.com/surge-proxy/surge-go/internal/protocol/vmess"
    "github.com/surge-proxy/surge-go/internal/server"
)

func main() {
    // 1. 加载配置
    // 2. 创建 VMess 客户端
    vmessClient, err := vmess.NewClient(...)
    
    // 3. 启动 HTTP 代理服务器
    httpServer := server.NewHTTPServer(":8888", vmessClient)
    httpServer.Start()
}
```

---

## 📝 具体操作指令

### 阶段 1: 最小可用版本 (MVP)

**目标**: 实现一个能工作的 VMess HTTP 代理

#### 第 1 天: 接口设计与项目结构

```bash
# 1. 创建目录结构
cd /Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/surge-go

mkdir -p internal/protocol/vmess
mkdir -p internal/protocol/trojan
mkdir -p internal/protocol/vless
mkdir -p internal/server
mkdir -p internal/rule

# 2. 创建接口文件
touch internal/protocol/dialer.go
```

#### 第 2-4 天: 实现 VMess 协议

```bash
# 创建 VMess 相关文件
touch internal/protocol/vmess/client.go
touch internal/protocol/vmess/handshake.go
touch internal/protocol/vmess/aead.go
touch internal/protocol/vmess/websocket.go
touch internal/protocol/vmess/tls.go
```

**参考资源**:
- v2ray-core VMess 实现: https://github.com/v2fly/v2ray-core/tree/master/proxy/vmess
- VMess 协议文档: https://www.v2fly.org/developer/protocols/vmess.html

#### 第 5 天: 实现 HTTP 代理服务器

```bash
touch internal/server/http.go
touch internal/server/socks5.go
```

#### 第 6 天: 测试与集成

```bash
# 修改 main.go
# 测试运行
go run cmd/surge/main.go -c temp.conf
```

---

## 🛠️ 开发建议

### 1. 使用现有代码

不要从零开始实现协议，推荐复用以下项目的代码：

- **VMess**: [v2ray-core](https://github.com/v2fly/v2ray-core)
- **Trojan**: [trojan-go](https://github.com/p4gefau1t/trojan-go)
- **VLESS**: [Xray-core](https://github.com/XTLS/Xray-core)

### 2. 分阶段实现

```
第 1 阶段 (1 周): VMess + HTTP 代理
  └─> 能够通过 VMess 代理访问网站

第 2 阶段 (1 周): Trojan + VLESS + SOCKS5
  └─> 支持三种协议

第 3 阶段 (1 周): 规则引擎
  └─> 支持域名、IP 规则匹配

第 4 阶段 (1 周): 策略组
  └─> 支持 select、url-test、smart

第 5 阶段 (1 周): 完善功能
  └─> DNS、订阅、测试
```

### 3. 调试技巧

```bash
# 开启详细日志
export LOG_LEVEL=debug
go run cmd/surge/main.go -c temp.conf

# 使用 curl 测试代理
curl -x http://127.0.0.1:8888 https://www.google.com

# 抓包分析
tcpdump -i lo0 -w proxy.pcap port 8888
```

### 4. 单元测试

为每个模块编写测试：

```bash
# 测试 VMess 客户端
go test -v ./internal/protocol/vmess/...

# 测试 HTTP 服务器
go test -v ./internal/server/...
```

---

## 🔍 常见问题

### Q1: 协议实现太复杂怎么办?

**A**: 直接引用现有项目的代码:

```go
import (
    vmesscore "github.com/v2fly/v2ray-core/v5/proxy/vmess"
)
```

### Q2: 如何测试代理是否工作?

**A**: 使用简单的 HTTP 请求:

```bash
curl -x http://127.0.0.1:8888 -v https://www.google.com
```

### Q3: 性能如何优化?

**A**: 后期优化重点:
- 连接池 (connection pooling)
- 协程池 (goroutine pool)
- 零拷贝 (io.Copy 优化)
- 内存池 (sync.Pool)

---

## 📚 推荐阅读

1. **协议规范**:
   - [VMess 协议](https://www.v2fly.org/developer/protocols/vmess.html)
   - [Trojan 协议](https://trojan-gfw.github.io/trojan/protocol)
   - [VLESS 协议](https://xtls.github.io/config/features/vless.html)

2. **Go 代理开发**:
   - [Go HTTP Proxy](https://github.com/elazarl/goproxy)
   - [Go SOCKS5](https://github.com/armon/go-socks5)

3. **参考项目**:
   - [v2ray-core](https://github.com/v2fly/v2ray-core)
   - [Clash](https://github.com/Dreamacro/clash)
   - [Xray-core](https://github.com/XTLS/Xray-core)

---

## ✅ 验收标准

### 阶段 1 验收 (最小可用版本)

- [ ] 能够解析 temp.conf 配置文件
- [ ] 能够连接到 VMess 服务器
- [ ] 能够通过 HTTP 代理访问 HTTPS 网站
- [ ] 日志输出正常，无明显错误

### 阶段 2 验收 (完整协议支持)

- [ ] 支持 VMess、Trojan、VLESS 三种协议
- [ ] 支持 HTTP 和 SOCKS5 代理
- [ ] 能够切换不同的代理节点

### 阶段 3 验收 (规则引擎)

- [ ] 支持 DOMAIN、DOMAIN-SUFFIX、IP-CIDR 规则
- [ ] 支持 RULE-SET 远程规则集
- [ ] 规则匹配正确

### 阶段 4 验收 (策略组)

- [ ] 支持 select、url-test、smart 策略组
- [ ] 自动测速功能正常
- [ ] 订阅链接更新正常

---

## 🎉 总结

核心步骤:
1. **定义接口** → `protocol.Dialer`
2. **实现协议** → VMess/Trojan/VLESS
3. **创建服务器** → HTTP/SOCKS5
4. **集成主程序** → 替换 sing-box

按照这个顺序，逐步实现，每个阶段都能产出可测试的版本！

Good luck! 💪
