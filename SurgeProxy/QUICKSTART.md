# 快速开始指南 | Quick Start Guide

## 中文说明

### 构建应用

1. **打开 Xcode 项目**
   ```bash
   cd /Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/SurgeProxy
   open SurgeProxy.xcodeproj
   ```

2. **在 Xcode 中运行**
   - 选择 "SurgeProxy" scheme
   - 点击运行按钮 (⌘R)
   - 应用将自动构建并启动

### 使用应用

1. **启动代理服务器**
   - 点击绿色的 "Start Proxy" 按钮
   - 状态指示器变为绿色表示运行中

2. **配置浏览器**
   - 方式1：使用系统代理（推荐）
     - 在应用中开启 "Set as System Proxy" 开关
   - 方式2：手动配置浏览器
     - HTTP 代理: 127.0.0.1:8888
     - HTTPS 代理: 127.0.0.1:8888

3. **管理域名过滤**
   - 切换到 "Domains" 标签
   - 左侧添加要屏蔽的域名
   - 右侧添加直连域名

4. **查看日志**
   - 切换到 "Logs" 标签
   - 实时查看代理请求

---

## English Instructions

### Building the App

1. **Open Xcode Project**
   ```bash
   cd /Users/dzer0/Documents/IdeaProjects/wangchenfeng/surge/SurgeProxy
   open SurgeProxy.xcodeproj
   ```

2. **Run in Xcode**
   - Select "SurgeProxy" scheme
   - Click Run button (⌘R)
   - App will build and launch automatically

### Using the App

1. **Start Proxy Server**
   - Click green "Start Proxy" button
   - Status indicator turns green when running

2. **Configure Browser**
   - Option 1: Use System Proxy (Recommended)
     - Toggle "Set as System Proxy" in the app
   - Option 2: Manual Browser Configuration
     - HTTP Proxy: 127.0.0.1:8888
     - HTTPS Proxy: 127.0.0.1:8888

3. **Manage Domain Filtering**
   - Switch to "Domains" tab
   - Left side: Add domains to block
   - Right side: Add direct connection domains

4. **View Logs**
   - Switch to "Logs" tab
   - See real-time proxy requests

---

## 项目文件 | Project Files

### 核心文件 | Core Files

- `SurgeProxyApp.swift` - 应用入口 | App entry point
- `ContentView.swift` - 主界面 | Main UI
- `ProxyManager.swift` - 代理控制器 | Proxy controller
- `ProxyConfig.swift` - 配置模型 | Configuration model

### 视图文件 | View Files

- `ServerControlView.swift` - 服务器控制面板
- `ConfigurationView.swift` - 配置设置
- `DomainFilterView.swift` - 域名过滤管理
- `LogView.swift` - 日志查看器

### 资源文件 | Resources

- `proxy_server.py` - Python 代理服务器
- `config.json` - 默认配置

---

## 功能特性 | Features

✅ 原生 macOS 界面 | Native macOS Interface  
✅ 启动/停止代理 | Start/Stop Proxy  
✅ 可视化配置 | Visual Configuration  
✅ 域名过滤 | Domain Filtering  
✅ 实时日志 | Real-time Logs  
✅ 菜单栏集成 | Menu Bar Integration  
✅ 系统代理配置 | System Proxy Config  

---

## 故障排除 | Troubleshooting

### 代理无法启动 | Proxy Won't Start

- 检查 Python 3 是否安装: `python3 --version`
- 确认端口 8888 未被占用
- 查看日志标签页的错误信息

### 构建错误 | Build Errors

- 确保安装了完整的 Xcode（不只是命令行工具）
- 清理构建文件夹: Product → Clean Build Folder
- 重启 Xcode

---

## 技术栈 | Tech Stack

- **语言 | Language**: Swift 5.0
- **框架 | Framework**: SwiftUI
- **最低系统 | Min macOS**: 13.0
- **后端 | Backend**: Python 3

---

## 下一步 | Next Steps

1. 在 Xcode 中构建并运行应用
2. 测试所有功能
3. 使用浏览器测试代理
4. 根据需要自定义配置
