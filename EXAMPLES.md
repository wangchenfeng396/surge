# Surge Proxy Server - 示例和最佳实践

## 示例配置

### 1. 基础配置 - 简单代理
```json
{
  "port": 8888,
  "host": "0.0.0.0",
  "buffer_size": 8192,
  "timeout": 30,
  "blocked_domains": [],
  "direct_domains": ["localhost"],
  "rules": []
}
```

### 2. 广告屏蔽配置
```json
{
  "port": 8888,
  "host": "0.0.0.0",
  "buffer_size": 8192,
  "timeout": 30,
  "blocked_domains": [
    "ads.google.com",
    "doubleclick.net",
    "googleadservices.com",
    "googlesyndication.com",
    "advertising.com",
    "adservice.google.com"
  ],
  "direct_domains": ["localhost"],
  "rules": []
}
```

### 3. 企业内网配置
```json
{
  "port": 8888,
  "host": "127.0.0.1",
  "buffer_size": 8192,
  "timeout": 60,
  "blocked_domains": [
    "social-media.com",
    "streaming-site.com"
  ],
  "direct_domains": [
    "localhost",
    "127.0.0.1",
    "*.internal.company.com",
    "intranet.company.com",
    "gitlab.company.com"
  ],
  "rules": [
    {
      "type": "DOMAIN-SUFFIX",
      "pattern": ".company.com",
      "action": "DIRECT"
    }
  ]
}
```

### 4. 开发环境配置
```json
{
  "port": 8888,
  "host": "127.0.0.1",
  "buffer_size": 16384,
  "timeout": 120,
  "blocked_domains": [],
  "direct_domains": [
    "localhost",
    "127.0.0.1",
    "*.local",
    "*.test"
  ],
  "rules": []
}
```

## 使用场景

### 场景 1: 本地开发调试

开发人员可以使用代理服务器来：
- 监控和记录 HTTP/HTTPS 请求
- 测试应用在代理环境下的行为
- 屏蔽外部广告和追踪器

```bash
# 启动代理
python3 proxy_server.py

# 配置应用使用代理
export http_proxy=http://127.0.0.1:8888
export https_proxy=http://127.0.0.1:8888

# 运行你的应用
./your-app
```

### 场景 2: 网络请求分析

```bash
# 启动代理服务器并查看日志
python3 proxy_server.py

# 在另一个终端，通过代理发送请求
curl -x http://127.0.0.1:8888 https://api.example.com/data
```

服务器日志会显示：
```
2024-01-11 12:00:00 - INFO - HTTPS: api.example.com:443
```

### 场景 3: 内容过滤

通过配置 `blocked_domains` 实现内容过滤：

```json
{
  "blocked_domains": [
    "malicious-site.com",
    "phishing-site.com",
    "unwanted-content.com"
  ]
}
```

## 常见问题

### Q1: 如何验证代理是否工作？

**方法 1: 使用 curl**
```bash
curl -v -x http://127.0.0.1:8888 http://example.com
```

**方法 2: 使用测试脚本**
```bash
python3 test_proxy.py
```

**方法 3: 检查服务器日志**
查看是否有请求日志输出

### Q2: 为什么某些网站无法访问？

可能原因：
1. 网站在 `blocked_domains` 列表中
2. 连接超时（增加 `timeout` 值）
3. 网络问题
4. 防火墙阻止

### Q3: 如何提高性能？

1. 增加 buffer_size:
```json
{
  "buffer_size": 16384
}
```

2. 使用更高效的服务器（生产环境考虑使用 nginx 等）

### Q4: 如何保护代理服务器？

1. 仅监听本地地址：
```json
{
  "host": "127.0.0.1"
}
```

2. 使用防火墙规则限制访问
3. 添加认证机制（需要扩展代码）

### Q5: 支持 SOCKS5 协议吗？

当前版本仅支持 HTTP/HTTPS 代理。SOCKS5 支持可以在后续版本添加。

## 最佳实践

### 1. 安全性
- 不要在公网暴露代理服务器
- 定期更新屏蔽域名列表
- 监控异常流量

### 2. 性能优化
- 根据实际需求调整 buffer_size
- 合理设置 timeout 值
- 对于高并发场景，考虑使用专业代理服务器

### 3. 日志管理
- 定期清理日志文件
- 使用日志轮转
- 监控错误日志

### 4. 配置管理
- 使用 `config.example.json` 作为模板
- 为不同环境创建不同的配置文件
- 版本控制配置文件（不包含敏感信息）

## 扩展功能建议

### 可以添加的功能：

1. **用户认证**
   - Basic Auth
   - Token-based authentication

2. **请求修改**
   - 添加/修改/删除 HTTP 头
   - URL 重写

3. **流量统计**
   - 记录流量使用情况
   - 生成统计报告

4. **缓存支持**
   - 缓存常用资源
   - 减少重复请求

5. **Web 管理界面**
   - 实时监控
   - 配置管理
   - 日志查看

6. **规则热重载**
   - 无需重启即可更新配置
   - 支持更复杂的规则匹配

## 技术细节

### 代理工作流程

1. 客户端连接到代理服务器
2. 发送 HTTP/HTTPS 请求
3. 代理服务器解析请求
4. 应用规则（屏蔽、直连、转发）
5. 建立与目标服务器的连接
6. 转发请求和响应
7. 关闭连接

### HTTP vs HTTPS 处理

**HTTP (端口 80):**
- 直接转发 HTTP 请求
- 可以读取和修改内容

**HTTPS (端口 443):**
- 使用 CONNECT 方法建立隧道
- 只转发加密数据
- 无法读取内容（端到端加密）

### 多线程模型

- 主线程监听新连接
- 每个客户端连接创建一个新线程
- 使用 select 实现双向数据转发
- 超时自动断开连接

## 参考资源

- [HTTP 代理协议](https://developer.mozilla.org/en-US/docs/Web/HTTP/Proxy_servers_and_tunneling)
- [CONNECT 方法](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/CONNECT)
- [Surge 文档](https://manual.nssurge.com/)
- [Python Socket 编程](https://docs.python.org/3/library/socket.html)
