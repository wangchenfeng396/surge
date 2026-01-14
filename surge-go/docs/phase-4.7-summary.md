# 阶段 4.7 完成总结 - Include-All-Proxies 支持

## ✅ 完成目标

实现了策略组的 `include-all-proxies` 功能，支持自动将所有定义的代理加入到策略组中。

### 核心变更

1.  **配置工厂工厂增强 (`NewGroupFromConfig`)**
    *   修改了 `internal/policy/factory.go` 中的 `NewGroupFromConfig` 函数签名，增加了 `allProxies []string` 参数。
    *   实现了 `IncludeAll` 逻辑：如果配置了 `include-all-proxies = true`，则会自动将 `allProxies` 中的代理追加到策略组的节点列表中，并进行去重处理。
    *   **处理顺序**: 先处理配置的静态列表 -> 再追加所有代理 -> 最后应用正则过滤 (如果有)。这意味着 `include-all-proxies` 引入的节点也会被 `policy-regex-filter` 过滤。

2.  **验证**
    *   更新了 `internal/policy/factory_test.go`，适配了新的函数签名。
    *   新增了 `TestNewGroupFromConfig_IncludeAll` 测试用例，验证了：
        *   手动配置的节点保留。
        *   `allProxies` 中的节点被追加。
        *   重复节点（手动配置 vs allProxies）被去重。

### 📝 代码统计

*   **修改文件**:
    *   `internal/policy/factory.go`: 核心逻辑实现。
    *   `internal/policy/factory_test.go`: 单元测试更新与新增。

## 🚀 下一步

*   **Phase 8**: 主程序集成。
    *   现在 `internal/policy` 模块的功能已基本完备（Select, URL-Test, Smart, 订阅, 正则过滤, 嵌套检测, Include-All）。
    *   下一步将在 `cmd/surge/main.go` 中把所有模块串联起来，构建完整的代理应用。
