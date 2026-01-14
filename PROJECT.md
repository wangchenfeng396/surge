# Project Overview | 项目概览

## English

### What is Surge?

This project implements a lightweight HTTP/HTTPS proxy server inspired by Surge, a popular network debugging and proxy tool. The implementation provides core proxy functionality with configuration support, domain filtering, and request logging.

### Key Features

1. **HTTP/HTTPS Proxy**
   - Full HTTP/1.1 proxy support
   - HTTPS tunneling via CONNECT method
   - Transparent request/response forwarding

2. **Configuration Management**
   - JSON-based configuration
   - Customizable port and host settings
   - Adjustable buffer sizes and timeouts

3. **Domain Filtering**
   - Block unwanted domains
   - Define direct-connection domains
   - Custom routing rules

4. **Logging & Monitoring**
   - Real-time request logging
   - Error tracking
   - Connection status monitoring

5. **Multi-threaded Architecture**
   - Handles multiple concurrent connections
   - Non-blocking I/O using select()
   - Efficient resource management

### Project Structure

```
surge/
├── proxy_server.py        # Main proxy server implementation
├── config.json            # Default configuration file
├── config.example.json    # Example configuration template
├── demo.py               # Demonstration script
├── test_proxy.py         # Test suite
├── start.sh              # Start script
├── requirements.txt      # Dependencies (none required)
├── README.md             # Main documentation (Chinese)
├── USAGE.md              # Usage guide
├── EXAMPLES.md           # Configuration examples
└── .gitignore           # Git ignore rules
```

### Technology Stack

- **Language**: Python 3
- **Libraries**: Standard library only (socket, threading, select, json, logging)
- **Protocol**: HTTP/1.1, HTTPS (CONNECT method)
- **Architecture**: Multi-threaded socket server

### Getting Started

1. **Start the proxy server**
   ```bash
   python3 proxy_server.py
   ```

2. **Run the demo**
   ```bash
   python3 demo.py
   ```

3. **Configure your browser**
   - Set HTTP proxy to `127.0.0.1:8888`
   - Set HTTPS proxy to `127.0.0.1:8888`

### Use Cases

- Local development and debugging
- Network request monitoring
- Ad and tracker blocking
- Custom routing rules
- Learning proxy server implementation

---

## 中文

### 什么是 Surge？

本项目实现了一个轻量级的 HTTP/HTTPS 代理服务器，参考了流行的网络调试和代理工具 Surge 的设计。该实现提供了核心代理功能，包括配置支持、域名过滤和请求日志记录。

### 主要功能

1. **HTTP/HTTPS 代理**
   - 完整的 HTTP/1.1 代理支持
   - 通过 CONNECT 方法支持 HTTPS 隧道
   - 透明的请求/响应转发

2. **配置管理**
   - 基于 JSON 的配置
   - 可自定义端口和主机设置
   - 可调整的缓冲区大小和超时时间

3. **域名过滤**
   - 屏蔽不需要的域名
   - 定义直连域名
   - 自定义路由规则

4. **日志和监控**
   - 实时请求日志
   - 错误跟踪
   - 连接状态监控

5. **多线程架构**
   - 处理多个并发连接
   - 使用 select() 的非阻塞 I/O
   - 高效的资源管理

### 项目结构

```
surge/
├── proxy_server.py        # 主代理服务器实现
├── config.json            # 默认配置文件
├── config.example.json    # 配置示例模板
├── demo.py               # 演示脚本
├── test_proxy.py         # 测试套件
├── start.sh              # 启动脚本
├── requirements.txt      # 依赖项（无需外部依赖）
├── README.md             # 主要文档（中文）
├── USAGE.md              # 使用指南
├── EXAMPLES.md           # 配置示例
└── .gitignore           # Git 忽略规则
```

### 技术栈

- **语言**: Python 3
- **库**: 仅使用标准库（socket、threading、select、json、logging）
- **协议**: HTTP/1.1、HTTPS（CONNECT 方法）
- **架构**: 多线程套接字服务器

### 快速开始

1. **启动代理服务器**
   ```bash
   python3 proxy_server.py
   ```

2. **运行演示**
   ```bash
   python3 demo.py
   ```

3. **配置浏览器**
   - 设置 HTTP 代理为 `127.0.0.1:8888`
   - 设置 HTTPS 代理为 `127.0.0.1:8888`

### 使用场景

- 本地开发和调试
- 网络请求监控
- 广告和追踪器屏蔽
- 自定义路由规则
- 学习代理服务器实现

### 与 Surge 的比较

| 功能 | Surge 原版 | 本项目 |
|------|-----------|--------|
| HTTP 代理 | ✅ | ✅ |
| HTTPS 代理 | ✅ | ✅ |
| 域名过滤 | ✅ | ✅ |
| 规则配置 | ✅ | ✅（基础版） |
| GUI 界面 | ✅ | ❌ |
| PAC 文件 | ✅ | ❌ |
| 流量统计 | ✅ | ❌ |
| 用户认证 | ✅ | ❌ |

本项目是 Surge 的简化实现，专注于核心代理功能，适合学习和小规模使用。

### 开发说明

本项目使用纯 Python 标准库实现，无需安装任何第三方依赖。代码结构清晰，易于理解和扩展。

主要组件：
- `ProxyConfig`: 配置管理类
- `ProxyServer`: 代理服务器主类
- `handle_http`: HTTP 请求处理
- `handle_https`: HTTPS 连接处理
- `forward_data`: 数据转发逻辑

### 安全提示

1. 本代理服务器用于学习和开发目的
2. 默认绑定到 0.0.0.0，可能暴露在网络中
3. 没有内置认证机制
4. 建议仅在可信网络环境中使用
5. 生产环境请使用专业代理服务器（如 Squid、nginx）

### 许可证

MIT License - 可自由使用、修改和分发

### 参考资源

- [Surge 官方文档](https://manual.nssurge.com/)
- [HTTP 代理协议](https://developer.mozilla.org/en-US/docs/Web/HTTP/Proxy_servers_and_tunneling)
- [Python Socket 编程](https://docs.python.org/3/library/socket.html)
