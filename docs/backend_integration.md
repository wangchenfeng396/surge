# 后端服务集成与配置管理

## 概述
本次更新实现了应用启动时自动启动后端 `surge-go` 服务，并将 UI 配置界面直接绑定到后端 API，确保所有配置更改都能持久化保存到 `surge.conf` 文件中。

## 核心功能

### 1. 后端自动启动 (Backend Auto-start)
- **实现位置**: `Services/BackendProcessManager.swift`
- **功能描述**: 
  - 应用启动时，`GoProxyManager` 会调用 `BackendProcessManager` 启动后端进程。
  - **开发环境支持**: 在 Xcode 调试模式下，如果应用包中找不到 `surge-go` 二进制文件，会自动降级查找硬编码的开发路径 (`.../surge/surge-go/bin/surge-go`)。
  - **自动配置修复**: 启动时会检查工作目录（`Application Support/SurgeProxy`）下是否存在 `surge.conf` 配置文件。如果不存在，会自动从二进制文件所在目录或资源包中复制一份默认配置。这解决了因缺少配置文件导致后端启动失败的问题。

### 2. 高级通用设置 (Advanced General Settings)
- **实现位置**: `Views/AdvancedGeneralSettingsView.swift`
- **功能描述**:
  - 移除了本地的 `@State` 配置存储。
  - 视图加载时 (`.task`) 通过 `APIClient.shared.fetchGeneralConfig()` 获取当前后端配置。
  - 点击“保存”按钮时，通过 `APIClient.shared.updateGeneralConfig()` 将更改推送到后端并持久化。

### 3. 代理组管理 (Proxy Group Management)
- **实现位置**: `Views/ProxyGroupManagerView.swift`
- **功能描述**:
  - 数据模型从本地 `ProxyGroup` 切换为与 API 共享的 `ProxyGroupConfigModel`。
  - 实现了完整的 CRUD（增删改查）操作，所有操作均通过 `APIClient` 直接与后端交互：
    - 获取列表: `fetchAllProxyGroups()`
    - 添加组: `addProxyGroup()`
    - 更新组: `updateProxyGroup()`
    - 删除组: `deleteProxyGroup()`
  - 修复了 UI 编辑器中的字段映射问题，确保所有高级选项（如 `noAlert`, `hidden` 等）都能正确保存。

### 4. 进程生命周期管理 (Process Lifecycle Management)
- **实现位置**: `Models/GoProxyManager.swift`
- **功能描述**:
  - 监听 `NSApplication.willTerminateNotification` 通知。
  - 在应用退出（Cmd+Q 或菜单退出）时，自动触发后端清理流程。
  - 调用 `BackendProcessManager.stopBackend()` 向后端进程发送终止信号（SIGTERM），确保 `surge-go` 进程随主应用一同关闭，避免僵尸进程占用端口。

  - 调用 `BackendProcessManager.stopBackend()` 向后端进程发送终止信号（SIGTERM），确保 `surge-go` 进程随主应用一同关闭，避免僵尸进程占用端口。

### 5. 后端状态监控 (Backend Status Monitor)
- **实现位置**: `Views/SidebarView.swift`
- **功能描述**:
  - 在侧边栏底部新增了状态栏。
  - **状态指示器**:
    - 🟢 绿色圆点: 后端运行正常 (`isRunning = true`)
    - 🔴 红色圆点: 后端停止或未就绪
  - **重启按钮**: 点击旋转箭头图标可强制重启后端服务 (`GoProxyManager.restartProxy()`)。这对于调试或后端意外挂起时非常有用。

## 验证步骤

1. **启动测试**:
   - 在 Xcode 中运行应用。

   - 观察控制台日志，确认出现 "Backend process started" 和 "Backend is ready"。
   - 确认后端使用了开发路径下的二进制文件，并且在需要时自动复制了配置文件。

2. **配置持久化测试**:
   - 进入 **Advanced General Settings**，修改任意参数（如 Log Level），保存。
   - 重启应用，再次进入该页面，确认修改是否保留。
   - 进入 **Proxy Groups**，添加一个新的代理组。
   - 重启应用，确认新添加的代理组依然存在。
