# 测试指南

## 概述

本文档说明如何对 Surge 代理系统进行测试，包括单元测试、集成测试和手动测试步骤。

---

## 后端测试 (surge-go)

### 单元测试

#### 运行所有测试

```bash
cd surge-go
go test ./...
```

#### 运行特定包的测试

```bash
# 测试配置管理器
go test ./internal/config -v

# 测试系统代理
go test ./internal/system -v

# 测试 API 服务器
go test ./internal/api -v
```

#### 测试覆盖率

```bash
# 生成覆盖率报告
go test ./... -coverprofile=coverage.out

# 查看覆盖率
go tool cover -html=coverage.out
```

### 集成测试

#### 启动测试服务器

```bash
# 使用测试配置启动
./surge-go -c testdata/test_surge.conf
```

#### API 端点测试

使用 curl 测试各个端点：

```bash
# 健康检查
curl http://localhost:9090/api/health

# 获取配置
curl http://localhost:9090/api/config

# 获取 General 配置
curl http://localhost:9090/api/config/general

# 添加代理
curl -X POST http://localhost:9090/api/config/proxies \
  -H "Content-Type: application/json" \
  -d '{
    "name": "TestProxy",
    "type": "vmess",
    "server": "test.com",
    "port": 443,
    "username": "test-uuid"
  }'

# 启用系统代理
curl -X POST http://localhost:9090/api/system-proxy/enable \
  -H "Content-Type: application/json" \
  -d '{"port": 8888}'

# 获取系统代理状态
curl http://localhost:9090/api/system-proxy/status
```

---

## 前端测试 (SurgeProxy)

### 手动测试清单

#### 1. General 配置测试
- [ ] 打开 General 配置界面
- [ ] 修改 DNS 服务器
- [ ] 修改日志级别
- [ ] 修改测试 URL
- [ ] 点击保存，验证配置生效
- [ ] 刷新页面，验证配置持久化

#### 2. 代理管理测试
- [ ] 添加 VMess 代理
- [ ] 添加 Trojan 代理
- [ ] 添加 Shadowsocks 代理
- [ ] 编辑现有代理
- [ ] 删除代理
- [ ] 测试代理延迟

#### 3. 代理组测试
- [ ] 创建 select 类型代理组
- [ ] 创建 url-test 类型代理组
- [ ] 创建 fallback 类型代理组
- [ ] 编辑代理组
- [ ] 删除代理组

#### 4. 规则管理测试
- [ ] 添加 DOMAIN 规则
- [ ] 添加 DOMAIN-SUFFIX 规则
- [ ] 添加 IP-CIDR 规则
- [ ] 添加 GEOIP 规则
- [ ] 添加 FINAL 规则
- [ ] 编辑规则
- [ ] 删除规则
- [ ] 规则排序

#### 5. 控制面板测试
- [ ] 启动代理服务
- [ ] 停止代理服务
- [ ] 启用系统代理
- [ ] 禁用系统代理
- [ ] 启用 TUN 模式 (需要权限)
- [ ] 禁用 TUN 模式

#### 6. 配置文件管理测试
- [ ] 从文件导入配置
- [ ] 从 URL 导入配置
- [ ] 导出当前配置
- [ ] 验证配置预览

#### 7. 代理测速测试
- [ ] 测试单个代理
- [ ] 批量测试所有代理
- [ ] 验证延迟显示
- [ ] 自定义测试 URL

#### 8. 规则导入导出测试
- [ ] 从文本导入规则
- [ ] 从文件导入规则
- [ ] 导出规则
- [ ] 验证格式正确性

---

## 性能测试

### 后端性能

#### 并发请求测试

使用 Apache Bench 测试 API 性能：

```bash
# 测试健康检查端点
ab -n 1000 -c 10 http://localhost:9090/api/health

# 测试配置获取
ab -n 100 -c 5 http://localhost:9090/api/config/general
```

#### 内存泄漏检测

```bash
# 使用 pprof
go test -memprofile mem.prof ./internal/config
go tool pprof mem.prof
```

### 代理性能测试

```bash
# 测试代理连接
curl -x http://localhost:8888 http://www.gstatic.com/generate_204

# 测试 SOCKS5
curl -x socks5://localhost:8888 http://www.gstatic.com/generate_204

# 延迟测试
time curl -x http://localhost:8888 http://www.google.com
```

---

## 兼容性测试

### 配置文件兼容性

测试各种 Surge 配置格式：

```bash
# 测试标准配置
./surge-go -c testdata/standard.conf -t

# 测试复杂订阅配置
./surge-go -c testdata/subscription.conf -t

# 测试包含所有功能的配置
./surge-go -c testdata/full_features.conf -t
```

### 系统兼容性

在不同系统上测试：
- macOS (系统代理功能)
- Linux (基础功能)
- Windows (基础功能)

---

## 错误处理测试

### 无效输入测试

```bash
# 无效的代理配置
curl -X POST http://localhost:9090/api/config/proxies \
  -H "Content-Type: application/json" \
  -d '{"name": ""}'  # 空名称

# 无效的规则
curl -X POST http://localhost:9090/api/config/rules \
  -H "Content-Type: application/json" \
  -d '{"type": "INVALID"}'  # 无效类型

# 不存在的代理
curl -X DELETE http://localhost:9090/api/config/proxies/NonExistent
```

### 网络错误测试

- 测试后端离线时前端的行为
- 测试网络超时
- 测试连接中断恢复

---

## 回归测试

每次发布前运行完整测试套件：

```bash
# 后端测试
cd surge-go
go test ./... -v

# 编译检查
go build -o bin/surge-go ./cmd/surge

# 启动服务
./bin/surge-go -c surge.conf &

# 等待启动
sleep 2

# 运行集成测试
curl http://localhost:9090/api/health

# 停止服务
pkill surge-go
```

---

## 测试数据

### 测试配置文件

在 `surge-go/testdata/` 目录下准备测试配置：

- `minimal.conf` - 最小配置
- `standard.conf` - 标准配置
- `full_features.conf` - 完整功能配置
- `invalid.conf` - 无效配置（用于错误测试）

### 测试代理

使用测试代理确保不影响生产：

```ini
TestProxy = vmess, test.example.com, 443, username=test-uuid
TestDirect = direct
TestReject = reject
```

---

## 已知问题

### 系统代理 (macOS)
- 需要管理员权限
- 可能被安全软件拦截
- 需要测试网络服务名称检测

### TUN 模式
- 需要 root 权限
- 当前为框架实现，需要完整的配置转换
- 需要测试虚拟网卡创建

### WebSocket
- 当前使用现有实现
- 需要测试断线重连
- 需要测试消息推送频率

---

## 测试报告模板

```markdown
## 测试报告

**测试日期**: YYYY-MM-DD
**测试人员**: 
**版本**: 

### 测试环境
- OS: 
- Go 版本: 
- Swift 版本: 

### 测试结果

#### 单元测试
- [ ] 通过
- [ ] 失败

#### 集成测试
- [ ] 通过
- [ ] 失败

#### 手动测试
- [ ] 通过
- [ ] 失败

### 发现的问题
1. 
2. 

### 建议
1. 
2. 
```

---

## 持续集成

### GitHub Actions 配置示例

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Set up Go
        uses: actions/setup-go@v2
        with:
          go-version: 1.21
      
      - name: Run tests
        run: |
          cd surge-go
          go test ./... -v
      
      - name: Build
        run: |
          cd surge-go
          go build -o bin/surge-go ./cmd/surge
```

---

## 总结

完整的测试流程应包括：
1. 单元测试 (自动化)
2. 集成测试 (半自动)
3. 手动功能测试
4. 性能测试
5. 兼容性测试
6. 回归测试

定期执行测试确保代码质量和功能稳定性。
