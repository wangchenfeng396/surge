# API 接口测试指南 (API & Integration)

后端提供 RESTful API 用于前端控制、状态监控及调试。
默认地址: `http://127.0.0.1:9090`

## 1. 核心控制 API

| 方法 | 路径 | 描述 | 参数示例 |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/proxies` | 获取所有代理列表 | - |
| `GET` | `/api/config/proxy-groups` | 获取策略组信息 | - |
| `POST` | `/api/config/proxy-groups/{name}/select` | 切换策略组节点 | `{"proxy": "NodeName"}` |
| `GET` | `/api/stats` | 获取流量统计 | - |

### 示例: 获取当前速度
```bash
curl http://127.0.0.1:9090/api/stats
# 响应: {"upload_speed": 1024, "download_speed": 2048, ...}
```

## 2. 调试与验证 API

### 规则匹配 (Rule Match)
最核心的调试工具，用于验证 URL 匹配逻辑。
```bash
curl -X POST http://127.0.0.1:9090/api/rules/match \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://www.youtube.com/watch?v=123",
    "source_ip": "192.168.1.10",
    "process": "Chrome"
  }'
```
**响应:**
```json
{
  "adapter": "Proxy",
  "rule": "DOMAIN-SUFFIX,youtube.com"
}
```

### DNS 查询 (DNS Query)
测试内置 DNS 解析结果。
```bash
curl "http://127.0.0.1:9090/api/dns/query?host=google.com"
```

## 3. 功能开关 API

| 方法 | 路径 | 描述 | 参数示例 |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/tun/enable` | 开启 TUN 模式 | - |
| `POST` | `/api/tun/disable` | 关闭 TUN 模式 | - |
| `GET` | `/api/tun/status` | 查询 TUN 状态 | - |

### 示例: 开启 TUN
```bash
curl -X POST http://127.0.0.1:9090/api/tun/enable
```
*(注意: 实际开启可能需要 sudo 权限启动的主进程支持)*
