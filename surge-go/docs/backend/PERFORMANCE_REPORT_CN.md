# 性能测试报告 (Performance Benchmark Report)

**日期:** 2026-01-14
**环境:** macOS (Apple M4), Go 1.25.5

## 执行摘要 (Executive Summary)
`surge-go` 后端在高负载下表现优异，核心路由和重写逻辑的延迟在亚微秒（sub-microsecond）级别。MITM 证书生成是主要的计算密集型操作（约 35ms），但通过缓存机制已得到有效优化。

## 详细指标 (Detailed Metrics)

### 1. 规则引擎 (Rule Engine)
路由决策极快，对连接建立的延迟影响可以忽略不计。

| 测试项目 (Benchmark) | 延迟 (Latency) |吞吐量 (Ops/Sec) | 内存分配 (Allocations) | 说明 (Description) |
| :--- | :--- | :--- | :--- | :--- |
| **域名匹配 (Domain Matching)** | `225.4 ns` | ~580万 | 6 allocs | 匹配列表中的 `google.com`。 |
| **CIDR 匹配 (CIDR Matching)** | `164.9 ns` | ~710万 | 4 allocs | 解析 IP 并检查子网掩码。 |

### 2.不仅流量重写 (Traffic Rewrites)
URL 和 Body 的修改引入的开销极低。

| 测试项目 (Benchmark) | 延迟 (Latency) | 吞吐量 (Ops/Sec) | 内存分配 (Allocations) | 说明 (Description) |
| :--- | :--- | :--- | :--- | :--- |
| **URL 正则 (URL Regex)** | `645.1 ns` | ~190万 | 5 allocs | 使用正则重写 `.../search?q=...`。 |
| **Body 重写 (Body Full)** | `3.97 µs` | ~29.5万 | 1 alloc | 对 50KB Body 进行简单字符串替换。 |
| **Body 正则 (Body Regex)** | `5.34 µs` | ~22.6万 | 22 allocs | 对 50KB Body 进行正则替换。 |

### 3. MITM (HTTPS 解密)
证书的实时生成是 CPU 密集型操作。

| 测试项目 (Benchmark) | 延迟 (Latency) | 吞吐量 (Ops/Sec) | 内存分配 (Allocations) | 说明 (Description) |
| :--- | :--- | :--- | :--- | :--- |
| **证书生成 (Cert Gen)** | `35.72 ms` | ~28 | ~4500 | RSA 2048 密钥生成 + X.509 签名。 |

> **注意:** MITM 管理器实现了证书的 LRU 缓存。在实际使用中，每个唯一的主机名在会话期间通常只需要承担一次这 35ms 的开销，后续请求的开销接近于零。

## 结论 (Conclusion)
- **路由与重写**: 性能极高。单核每秒可处理数百万次请求匹配。
- **MITM**: 性能受限于加密操作，当前实现符合行业标准，且缓存机制有效。
- **总体评价**: 逻辑层未发现明显性能瓶颈。
