# Surge Go 后端测试与开发文档

本文档集合了 Surge Go 后端服务的所有测试、验证及开发指南。

## 目录结构

### 1. 基础功能测试
- **[核心功能测试指南 (Core Testing)](TESTING_CORE_CN.md)**
    - 代理服务启动与连接
    - 基础规则路由 (Domain, IP-CIDR)
    - 策略组 (Proxy Groups) 验证

### 2. 高级特性测试
- **[高级特性测试指南 (Features Testing)](TESTING_FEATURES_CN.md)**
    - URL 重写 (URL/Body Rewrite)
    - MITM 解密与证书生成
    - TUN 模式 (虚拟网卡接管)
    - Script 脚本 (预留)

### 3. API 与集成 (Integration)
- **[API 参考手册 (API Reference)](API_REFERENCE_CN.md)**: 全量 RESTful API 接口定义。
- **[数据模型定义 (Data Models)](DATA_MODELS_CN.md)**: 请求响应 JSON 结构说明。
- **[接口测试指南 (API Testing)](TESTING_API_CN.md)**: 针对性调试与验证指南。

### 4. 性能报告
- **[性能基准测试报告 (Performance Report)](PERFORMANCE_REPORT_CN.md)**
    - 规则引擎吞吐量
    - 重写与 MITM 延迟数据

## 快速开始

### 启动后端
```bash
# 默认读取 surge.conf
./surge-go
```

### 运行验证套件
```bash
go test -v ./cmd/config_verification/...
```
