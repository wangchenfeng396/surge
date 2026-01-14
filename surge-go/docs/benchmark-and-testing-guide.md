# Surge 代理测试与基准测试指南

本文档说明如何运行 surge-go 项目的集成测试和性能基准测试。

## 1. 集成测试 (Integration Tests)

集成测试用于验证代理服务器、规则引擎和策略组的协同工作正确性。

### 运行所有集成测试
```bash
go test -v ./internal/test/...
```

### 运行特定测试
*   **直连测试 (Direct Connection)**:
    ```bash
    go test -v -run TestIntegration_Direct ./internal/test/...
    ```
*   **SOCKS5 代理测试**:
    ```bash
    go test -v -run TestIntegration_SOCKS5 ./internal/test/...
    ```
*   **规则分流测试 (Rule Dispatch)**:
    (注意: 需要干净的网络环境，端口冲突可能导致挂起)
    ```bash
    go test -v -run TestIntegration_RuleDispatch ./internal/test/...
    ```

## 2. 性能基准测试 (Performance Benchmarks)

基准测试用于测量吞吐量、规则匹配速度和引擎开销。

### 运行所有基准测试
```bash
go test -bench=. -benchtime=1s -v ./internal/test/...
```

### 运行特定基准测试
*   **规则匹配速度**:
    ```bash
    go test -bench=BenchmarkRuleMatching -v ./internal/test/...
    ```
*   **吞吐量测试 (直连 vs 引擎转发)**:
    ```bash
    go test -bench=BenchmarkThroughput -v ./internal/test/...
    ```

### 重要参数说明
*   `-benchtime`: 调整测试持续时间 (例如 `100ms`, `5s`)。
*   `-count`: 运行次数 (例如 `-count=5`)。
*   `-cpu`: 模拟不同 CPU 核心数 (例如 `-cpu=1,2,4`)。

## 3. 压力测试注意事项
进行未来压力测试时：
1.  使用 `BenchmarkThroughput_Engine` 作为基准。
2.  增加 `-benchtime` 到 `60s` 或更长以测试稳定性。
3.  运行基准测试时，建议在外部监控系统资源 (CPU/内存) 使用情况。
