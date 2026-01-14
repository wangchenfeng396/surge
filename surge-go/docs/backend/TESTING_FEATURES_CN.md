# 高级特性测试指南 (Advanced Features)

本指南涵盖 URL 重写、MITM 解密及 TUN 模式的测试。

## 1. URL 重写 (URL Rewrite & Body Rewrite)

### 配置要求
确保 `surge.conf` 中包含测试规则：
```ini
[URL Rewrite]
^https://www.google.com/search\?q=(.*) https://duckduckgo.com/?q=$1 302

[Body Rewrite]
// 需配合 MitM 开启
```

### 测试 URL Rewrite (302 Redirect)
```bash
curl -v -x http://127.0.0.1:8888 "https://www.google.com/search?q=test"
```
**预期结果:**
- 响应码: `302 Found`
- Location: `https://duckduckgo.com/?q=test`

### 测试 URL Reject
```bash
# 假设配置: ^https://ad.com REJECT
curl -v -x http://127.0.0.1:8888 "https://ad.com"
```
**预期结果:**
- 响应码: `502 Bad Gateway` 或连接被重置 (根据配置)。

## 2. MITM (HTTPS 解密)

MITM 允许后端解密 HTTPS 流量以进行 Body Rewrite 或抓包。

### 前置条件
1. 后端已生成 CA 证书（启动时自动生成或加载）。
2. 客户端（如 curl 或 浏览器）已信任该 CA 证书。

### 测试步骤
1. **启用 MITM**: 在配置中开启 `[MITM]` 并添加主机名。
    ```ini
    [MITM]
    hostname = www.example.com
    ```
2. **发起请求**:
    ```bash
    # 使用 -k 忽略证书错误 (仅用于测试拦截逻辑)
    curl -v -k -x http://127.0.0.1:8888 https://www.example.com
    ```
3. **验证日志**:
    后端日志应显示: `MITM Intercept: www.example.com:443`。
    如果配置了 Body Rewrite，响应内容应被修改。

## 3. TUN 模式 (虚拟网卡)

TUN 模式允许接管系统所有流量（包括不支持代理的软件）。

### 状态
⚠️ **当前状态**: 已实现但默认禁用 (构建依赖问题)。
**启用方法**: 运行 `scripts/fix_tun_mode.sh`。

### 测试步骤
1. **启动后端** (需 root 权限以创建 utun 设备):
    ```bash
    sudo ./surge-go
    ```
2. **验证网卡**:
    ```bash
    ifconfig utun*
    # 应看到一个新的 utun 接口，IP 通常为 198.18.0.1
    ```
3. **验证路由**:
    系统路由表应被修改，默认流量指向该 utun 接口。
4. **通断测试**:
    ```bash
    ping 8.8.8.8
    # ICMP 可能需特殊处理，建议测试 TCP/UDP
    curl https://www.google.com
    ```
